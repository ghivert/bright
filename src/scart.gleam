import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/function
import gleam/list
import gleam/pair
import lustre/effect.{type Effect}
import lustre/element.{type Element}

@external(erlang, "scart_ffi", "coerce")
@external(javascript, "./scart.ffi.mjs", "coerce")
fn coerce(a: a) -> b

pub opaque type Scart(data, computed) {
  Scart(
    data: data,
    computed: computed,
    selections: List(Dynamic),
    past_selections: List(Dynamic),
    effects: List(Dynamic),
  )
}

pub fn init(data: data, computed: computed) {
  Scart(data:, computed:, selections: [], past_selections: [], effects: [])
}

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

pub fn compute(
  scart: Scart(data, computed),
  compute_: fn(data, computed) -> computed,
) -> Scart(data, computed) {
  compute_(scart.data, scart.computed)
  |> fn(computed) { Scart(..scart, computed:) }
}

pub fn guard(
  scart: Scart(data, computed),
  guard_: fn(data, computed) -> Effect(msg),
) -> Scart(data, computed) {
  guard_(scart.data, scart.computed)
  |> dynamic.from
  |> list.prepend(scart.effects, _)
  |> fn(effects) { Scart(..scart, effects:) }
}

pub fn lazy_compute(
  scart: Scart(data, computed),
  selector: fn(data) -> a,
  compute_: fn(data, computed) -> computed,
) -> Scart(data, computed) {
  lazy_wrap(scart, selector, compute, compute_)
}

pub fn lazy_guard(
  scart: Scart(data, computed),
  selector: fn(data) -> a,
  guard_: fn(data, computed) -> Effect(msg),
) -> Scart(data, computed) {
  lazy_wrap(scart, selector, guard, guard_)
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
      |> case value == dynamic.from(selected_data) {
        True -> function.identity
        False -> setter(_, compute_)
      }
    }
  }
}

pub fn view(
  scart: Scart(data, computed),
  viewer: fn(data, computed) -> Element(msg),
) -> Element(msg) {
  viewer(scart.data, scart.computed)
}

pub fn step(
  scart: #(Scart(data, computed), Effect(msg)),
  next: fn(Scart(data, computed)) -> #(model, Effect(msg)),
) {
  let #(scart, effs) = scart
  let #(model, effs_) = next(scart)
  #(model, effect.batch([effs, effs_]))
}

pub fn return(a) {
  #(a, effect.none())
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
