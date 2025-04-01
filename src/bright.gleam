import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/function
import gleam/list
import gleam/pair
import lustre/effect.{type Effect}

/// `Bright` holds a state — raw data — and computed data, and is used to compute caching.
/// `Bright` is instanciated using `init`, with initial state and computed data.
pub opaque type Bright(state, computed) {
  Bright(
    state: state,
    computed: computed,
    selections: List(Dynamic),
    past_selections: List(Dynamic),
  )
}

/// Creates the initial `Bright`. `state` & `computed` should be initialised with
/// their correct empty initial state.
pub fn init(state state: state, computed computed: computed) {
  Bright(state:, computed:, selections: [], past_selections: [])
}

/// Start the Bright update cycle. Use it as a way to trigger the start of `Bright`
/// computations, and chain them with other `bright` calls. `start` handles all
/// of the hard work, of turning a `Bright(state, computed)` into a
/// `#(Bright(state, computed), Effect(msg))`, and will take care that your
/// `Bright(state, computed)` is always consistent over multiple update cycles.
///
/// ```gleam
/// pub fn update(model: Bright(state, computed), msg: Msg) {
///   // Starts the update cycle, and returns #(Bright(state, computed), Effect(msg)).
///   use model <- bright.start(model)
///   bright.update(model, update_state(_, msg))
/// }
/// ```
pub fn start(
  bright: Bright(state, computed),
  next: fn(#(Bright(state, computed), Effect(msg))) ->
    #(Bright(state, computed), Effect(msg)),
) -> #(Bright(state, computed), Effect(msg)) {
  let old_computations = bright.past_selections
  use new_data <- pair.map_first(next(#(bright, effect.none())))
  panic_if_different_computations_count(old_computations, new_data.selections)
  let past_selections = list.reverse(new_data.selections)
  Bright(..new_data, past_selections:, selections: [])
}

/// Update state & effects during update cycle. Use it a way to update your state
/// stored in `Bright`, and chain them with other `bright` calls.
///
/// ```gleam
/// pub fn update(model: Bright(state, computed), msg: Msg) {
///   use model <- bright.start(model)
///   // Run an update, and returns #(Bright(state, computed), Effect(msg)).
///   bright.update(model, update_state(_, msg))
/// }
/// ```
pub fn update(
  bright: #(Bright(state, computed), Effect(msg)),
  update_: fn(state) -> #(state, Effect(msg)),
) -> #(Bright(state, computed), Effect(msg)) {
  let #(bright, effects) = bright
  let #(state, effect) = update_(bright.state)
  #(Bright(..bright, state:), effect.batch([effects, effect]))
}

/// Derives data from the `data` state, and potentially the current `computed`
/// state. `compute` will run **at every render**, so be careful with computations
/// as they can block paint or actors.
///
/// ```gleam
/// pub fn update(model: Bright(state, computed), msg: Msg) {
///   use model <- bright.start(model)
///   model
///   |> bright.update(update_state(_, msg))
///   |> bright.compute(fn (d, c) { Computed(..c, field1: computation1(d)) })
///   |> bright.compute(fn (d, c) { Computed(..c, field2: computation2(d)) })
///   |> bright.compute(fn (d, c) { Computed(..c, field3: computation3(d)) })
/// }
/// ```
pub fn compute(
  bright: #(Bright(state, computed), Effect(msg)),
  compute_: fn(state, computed) -> computed,
) -> #(Bright(state, computed), Effect(msg)) {
  use bright <- pair.map_first(bright)
  compute_(bright.state, bright.computed)
  |> fn(computed) { Bright(..bright, computed:) }
}

/// Plugs in existing `state` and `computed` state, to issue some side-effects,
/// when your application needs to run side-effects depending on the current state.
///
/// ```gleam
/// pub fn update(model: Bright(state, computed), msg: Msg) {
///   use model <- bright.start(model)
///   model
///   |> bright.update(update_state(_, msg))
///   |> bright.schedule(model, fn (state, computed) {
///     use dispatch <- effect.from
///     case state.field == 10 {
///       True -> dispatch(my_msg)
///       False -> Nil
///     }
///   })
/// }
/// ```
pub fn schedule(
  bright: #(Bright(state, computed), Effect(msg)),
  schedule_: fn(state, computed) -> Effect(msg),
) -> #(Bright(state, computed), Effect(msg)) {
  let #(bright, effects) = bright
  let effect = schedule_(bright.state, bright.computed)
  #(bright, effect.batch([effects, effect]))
}

/// Derives data like [`compute`](#compute) lazily. `lazy_compute` accepts a
/// selector as second argument. Each time the selector returns a different data
/// than previous run, the computation will run. Otherwise, nothing happens.
/// The computation function will receive `state`, `computed` and the selected
/// data (i.e. the result from your selector function), in case accessing the
/// selected data is needed.
///
/// ```gleam
/// pub fn update(model: Bright(state, computed), msg: Msg) {
///   use model <- bright.start(model)
///   model
///   |> bright.update(update_state(_, msg))
///   // Here, selected is always the result state.field / 10 (the result from selector).
///   |> bright.lazy_compute(selector, fn (d, c, selected) { Computed(..c, field1: computation1(d, selected)) })
///   |> bright.lazy_compute(selector, fn (d, c, selected) { Computed(..c, field2: computation2(d, selected)) })
///   |> bright.lazy_compute(selector, fn (d, c, selected) { Computed(..c, field3: computation3(d, selected)) })
/// }
///
/// /// Use it with lazy_compute to recompute only when the field when
/// /// { old_state.field / 10 } != { state.field / 10 }
/// fn selector(d, _) {
///   d.field / 10
/// }
/// ```
pub fn lazy_compute(
  bright: #(Bright(state, computed), Effect(msg)),
  selector: fn(state) -> selection,
  compute_: fn(state, computed, selection) -> computed,
) -> #(Bright(state, computed), Effect(msg)) {
  lazy_wrap(bright, selector, compute, compute_)
}

/// Plugs in existing `state` like [`schedule`](#schedule) lazily. `lazy_schedule` accepts
/// a selector as second argument. Each time the selector returns a different data
/// than previous run, the computation will run. Otherwise, nothing happens.
/// The scheduling function will receive `state`, `computed` and the selected
/// data (i.e. the result from your selector function), in case accessing the
/// selected data is needed.
///
/// ```gleam
/// pub fn update(model: Bright(state, computed), msg: Msg) {
///   use model <- bright.start(model)
///   model
///   |> bright.update(update_state(_, msg))
///   // selected is equal to state.field / 10 (the result from selector).
///   |> bright.lazy_schedule(selector, fn (state, computed, selected) {
///     use dispatch <- effect.from
///     case selected == 10 {
///       True -> dispatch(my_msg)
///       False -> Nil
///     }
///   })
/// }
///
/// /// Use it with lazy_schedule to recompute only when the field when
/// /// { old_state.field / 10 } != { state.field / 10 }
/// fn selector(state, _) {
///   state.field / 10
/// }
/// ```
pub fn lazy_schedule(
  bright: #(Bright(state, computed), Effect(msg)),
  selector: fn(state) -> selection,
  schedule_: fn(state, computed, selection) -> Effect(msg),
) -> #(Bright(state, computed), Effect(msg)) {
  lazy_wrap(bright, selector, schedule, schedule_)
}

/// Extracts `state` & `computed` states from `Bright`.
///
/// ```gleam
/// pub fn view(model: Bright(state, computed)) {
///   let #(state, computed) = bright.unwrap(model)
///   html.div([], [
///     // Use state or computed here.
///   ])
/// }
/// ```
pub fn unwrap(bright: Bright(state, computed)) -> #(state, computed) {
  #(bright.state, bright.computed)
}

/// Extracts `state` state from `Bright`.
///
/// ```gleam
/// pub fn view(model: Bright(state, computed)) {
///   let state = bright.state(model)
///   html.div([], [
///     // Use state here.
///   ])
/// }
/// ```
pub fn state(bright: Bright(state, computed)) -> state {
  bright.state
}

/// Extracts `computed` state from `Bright`.
///
/// ```gleam
/// pub fn view(model: Bright(state, computed)) {
///   let computed = bright.computed(model)
///   html.div([], [
///     // Use computed here.
///   ])
/// }
/// ```
pub fn computed(bright: Bright(state, computed)) -> computed {
  bright.computed
}

/// Allows to run multiple `update` on multiple `Bright` in the same update cycle.
/// Every call to step with compute a new `Bright`, and will let you chain the
/// steps.
///
/// ```gleam
/// pub type Model {
///   Model(
///     fst_bright: Bright(state, computed),
///     snd_bright: Bright(state, computed),
///   )
/// }
///
/// fn update(model: Model, msg: Msg) {
///   use fst_bright <- bright.step(update_fst(model.fst_bright, msg))
///   use snd_bright <- bright.step(update_snd(model.snd_bright, msg))
///   #(Model(fst_bright:, snd_bright:), effect.none())
/// }
/// ```
pub fn step(
  bright: #(Bright(state, computed), Effect(msg)),
  next: fn(Bright(state, computed)) -> #(model, Effect(msg)),
) -> #(model, Effect(msg)) {
  let #(bright, effs) = bright
  let #(model, effs_) = next(bright)
  #(model, effect.batch([effs, effs_]))
}

fn lazy_wrap(
  bright: #(Bright(state, computed), Effect(msg)),
  selector: fn(state) -> selection,
  setter: fn(
    #(Bright(state, computed), Effect(msg)),
    fn(state, computed) -> output,
  ) ->
    #(Bright(state, computed), Effect(msg)),
  compute_: fn(state, computed, selection) -> output,
) -> #(Bright(state, computed), Effect(msg)) {
  let selected_data = selector({ bright.0 }.state)
  let selections = [dynamic.from(selected_data), ..{ bright.0 }.selections]
  let compute_ = fn(data, computed) { compute_(data, computed, selected_data) }
  let bright = #(Bright(..bright.0, selections:), bright.1)
  case { bright.0 }.past_selections {
    [] -> setter(bright, compute_)
    [value, ..past_selections] -> {
      #(Bright(..bright.0, past_selections:), bright.1)
      |> case are_dependencies_equal(value, selected_data) {
        True -> function.identity
        False -> setter(_, compute_)
      }
    }
  }
}

fn panic_if_different_computations_count(
  old_computations: List(c),
  computations: List(d),
) -> Nil {
  let count = list.length(old_computations)
  use <- bool.guard(when: count == 0, return: Nil)
  let is_same_count = count == list.length(computations)
  use <- bool.guard(when: is_same_count, return: Nil)
  panic as "Memoized computed should be consistent over time, otherwise memo can not work."
}

/// Optimization on JS, to ensure that two data sharing the referential equality
/// will shortcut the comparison. Useful when performance are a thing in client
/// browser. Otherwise, rely on Erlang equality.
@external(javascript, "./bright.ffi.mjs", "areDependenciesEqual")
fn are_dependencies_equal(a: a, b: b) -> Bool {
  dynamic.from(a) == dynamic.from(b)
}
