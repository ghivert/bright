import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/function
import gleam/list
import gleam/pair
import lustre/effect.{type Effect}

@external(erlang, "scart_ffi", "coerce")
@external(javascript, "./scart.ffi.mjs", "coerce")
fn coerce(a: a) -> b

/// Optimization on JS, to ensure two data sharing the referential equality
/// will shortcut the comparison. Useful when performance are a thing in client
/// browser.
@external(javascript, "./scart.ffi.mjs", "areReferentiallyEqual")
fn are_referentially_equal(a: a, b: b) -> Bool {
  dynamic.from(a) == dynamic.from(b)
}

/// `Scart` holds raw data and computed data, and is used to compute caching.
/// `Scart` is instanciated using `init`, with initial data and computed data.
pub opaque type Scart(data, computed) {
  Scart(
    data: data,
    computed: computed,
    selections: List(Dynamic),
    past_selections: List(Dynamic),
    effects: List(Dynamic),
  )
}

/// Creates the initial `Scart`. `data` & `computed` should be initialised with
/// their correct empty initial state.
pub fn init(
  data data: data,
  computed computed: computed,
) -> Scart(data, computed) {
  Scart(data:, computed:, selections: [], past_selections: [], effects: [])
}

/// Entrypoint for the update cycle. Use it a way to trigger the start of `Scart`
/// computations, and chain them with other `scart` calls.
///
/// ```gleam
/// pub fn update(model: Scart(data, computed), msg: Msg) {
///   // Starts the update cycle, and returns #(Scart(data, computed), Effect(msg)).
///   use model <- scart.update(model, update_data(_, msg))
///   scart.return(model)
/// }
/// ```
pub fn update(
  scart: Scart(data, computed),
  update_: fn(data) -> #(data, Effect(msg)),
  next: fn(Scart(data, computed)) -> Scart(data, computed),
) -> #(Scart(data, computed), Effect(msg)) {
  let old_computations = scart.past_selections
  let #(data, effs) = update_(scart.data)
  let scart = Scart(..scart, data:)
  let new_data = next(scart)
  let all_effects = dynamic.from(new_data.effects) |> coerce |> list.reverse
  panic_if_different_computations_count(old_computations, new_data.selections)
  let past_selections = list.reverse(new_data.selections)
  Scart(..new_data, past_selections:, selections: [], effects: [])
  |> pair.new(effect.batch([effs, effect.batch(all_effects)]))
}

/// Derives data from the `data` state, and potentially the current `computed`
/// state. `compute` will run **at every render**, so be careful with computations
/// as they can block paint or actors.
///
/// ```gleam
/// pub fn update(model: Scart(data, computed), msg: Msg) {
///   use model <- scart.update(model, update_data(_, msg))
///   model
///   |> scart.compute(fn (d, c) { Computed(..c, field1: computation1(d)) })
///   |> scart.compute(fn (d, c) { Computed(..c, field2: computation2(d)) })
///   |> scart.compute(fn (d, c) { Computed(..c, field3: computation3(d)) })
/// }
/// ```
pub fn compute(
  scart: Scart(data, computed),
  compute_: fn(data, computed) -> computed,
) -> Scart(data, computed) {
  compute_(scart.data, scart.computed)
  |> fn(computed) { Scart(..scart, computed:) }
}

/// Plugs in existing `data` and `computed` state, to issue some side-effects,
/// when your application needs to run side-effects depending on the current state.
///
/// ```gleam
/// pub fn update(model: Scart(data, computed), msg: Msg) {
///   use model <- scart.update(model, update_data(_, msg))
///   use d, c <- scart.guard(model)
///   use dispatch <- effect.from
///   case d.field == 10 {
///     True -> dispatch(my_msg)
///     False -> Nil
///   }
/// }
/// ```
pub fn guard(
  scart: Scart(data, computed),
  guard_: fn(data, computed) -> Effect(msg),
) -> Scart(data, computed) {
  guard_(scart.data, scart.computed)
  |> dynamic.from
  |> list.prepend(scart.effects, _)
  |> fn(effects) { Scart(..scart, effects:) }
}

/// Derives data like [`compute`](#compute) lazily. `lazy_compute` accepts a
/// selector as second argument. Each time the selector returns a different data
/// than previous run, the computation will run. Otherwise, nothing happens.
///
/// ```gleam
/// pub fn update(model: Scart(data, computed), msg: Msg) {
///   use model <- scart.update(model, update_data(_, msg))
///   model
///   |> scart.lazy_compute(selector, fn (d, c) { Computed(..c, field1: computation1(d)) })
///   |> scart.lazy_compute(selector, fn (d, c) { Computed(..c, field2: computation2(d)) })
///   |> scart.lazy_compute(selector, fn (d, c) { Computed(..c, field3: computation3(d)) })
/// }
///
/// /// Use it with lazy_compute to recompute only when the field when
/// /// { old_data.field / 10 } != { data.field / 10 }
/// fn selector(d, _) {
///   d.field / 10
/// }
/// ```
pub fn lazy_compute(
  scart: Scart(data, computed),
  selector: fn(data) -> a,
  compute_: fn(data, computed) -> computed,
) -> Scart(data, computed) {
  lazy_wrap(scart, selector, compute, compute_)
}

/// Plugs in existing `data` like [`guard`](#guard) lazily. `lazy_guard` accepts
/// a selector as second argument. Each time the selector returns a different data
/// than previous run, the computation will run. Otherwise, nothing happens.
///
/// ```gleam
/// pub fn update(model: Scart(data, computed), msg: Msg) {
///   use model <- scart.update(model, update_data(_, msg))
///   use d, c <- scart.lazy_guard(model, selector)
///   use dispatch <- effect.from
///   case d.field == 10 {
///     True -> dispatch(my_msg)
///     False -> Nil
///   }
/// }
///
/// /// Use it with lazy_guard to recompute only when the field when
/// /// { old_data.field / 10 } != { data.field / 10 }
/// fn selector(d, _) {
///   d.field / 10
/// }
/// ```
pub fn lazy_guard(
  scart: Scart(data, computed),
  selector: fn(data) -> a,
  guard_: fn(data, computed) -> Effect(msg),
) -> Scart(data, computed) {
  lazy_wrap(scart, selector, guard, guard_)
}

/// Injects `Scart(data, computed)` in the `view` function, like a middleware.
/// Used to extract `data` & `computed` states from `Scart`.
///
/// ```gleam
/// pub fn view(model: Scart(data, computed)) {
///   use data, computed <- scart.view(model)
///   html.div([], [
///     // Use data or computed here.
///   ])
/// }
/// ```
pub fn view(scart: Scart(data, computed), viewer: fn(data, computed) -> a) -> a {
  viewer(scart.data, scart.computed)
}

/// Allows to run multiple `update` on multiple `Scart` in the same update cycle.
/// Every call to step with compute a new `Scart`, and will let you chain the
/// steps.
///
/// ```gleam
/// pub type Model {
///   Model(
///     fst_scart: Scart(data, computed),
///     snd_scart: Scart(data, computed),
///   )
/// }
///
/// fn update(model: Model, msg: Msg) {
///   use fst_scart <- scart.step(update_fst(model.fst_scart, msg))
///   use snd_scart <- scart.step(update_snd(model.snd_scart, msg))
///   scart.return(Model(fst_scart:, snd_scart:))
/// }
/// ```
pub fn step(
  scart: #(Scart(data, computed), Effect(msg)),
  next: fn(Scart(data, computed)) -> #(model, Effect(msg)),
) {
  let #(scart, effs) = scart
  let #(model, effs_) = next(scart)
  #(model, effect.batch([effs, effs_]))
}

/// Helper to write `scart` update cycle. Equivalent to `#(a, effect.none())`.
pub fn return(a) {
  #(a, effect.none())
}

fn lazy_wrap(
  scart: Scart(data, computed),
  selector: fn(data) -> a,
  setter: fn(Scart(data, computed), fn(data, computed) -> c) ->
    Scart(data, computed),
  compute_: fn(data, computed) -> c,
) -> Scart(data, computed) {
  let selected_data = selector(scart.data)
  let selections = [dynamic.from(selected_data), ..scart.selections]
  let scart = Scart(..scart, selections:)
  case scart.past_selections {
    [] -> setter(scart, compute_)
    [value, ..past_selections] -> {
      Scart(..scart, past_selections:)
      |> case are_referentially_equal(value, selected_data) {
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
