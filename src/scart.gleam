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

pub opaque type Store(data, computed) {
  Store(
    data: data,
    computed: computed,
    computations: List(Dynamic),
    old_computations: List(Dynamic),
    effects: List(Dynamic),
  )
}

pub fn init(data: data, computed: computed) {
  Store(data:, computed:, computations: [], old_computations: [], effects: [])
}

pub fn update(
  derivation: Store(data, computed),
  updater: fn(data) -> #(data, Effect(msg)),
  next: fn(Store(data, computed)) -> Store(data, computed),
) -> #(Store(data, computed), Effect(msg)) {
  let old_computations = derivation.old_computations
  let #(data, effs) = updater(derivation.data)
  let derivation = Store(..derivation, data:)
  let new_data = next(derivation)
  let all_effects = dynamic.from(new_data.effects) |> coerce |> list.reverse
  panic_if_different_computations_count(old_computations, new_data.computations)
  let old_computations = list.reverse(new_data.computations)
  Store(..new_data, old_computations:, computations: [], effects: [])
  |> pair.new(effect.batch([effs, effect.batch(all_effects)]))
}

pub fn compute(
  derivation: Store(data, computed),
  compute: fn(data) -> a,
  setter: fn(computed, a) -> computed,
) -> Store(data, computed) {
  compute(derivation.data)
  |> setter(derivation.computed, _)
  |> fn(computed) { Store(..derivation, computed:) }
}

pub fn lazy_compute(
  derivation: Store(data, computed),
  selector: fn(data) -> a,
  compute: fn(data) -> b,
  setter: fn(computed, b) -> computed,
) -> Store(data, computed) {
  let new_value = selector(derivation.data)
  let computations = [dynamic.from(new_value), ..derivation.computations]
  let derivation = Store(..derivation, computations:)
  let do_computation = fn(temp) {
    let memo = compute(derivation.data)
    let computed = setter(derivation.computed, memo)
    Store(..temp, computed:)
  }
  case derivation.old_computations {
    [] -> do_computation(derivation)
    [value, ..old_computations] -> {
      Store(..derivation, old_computations:)
      |> case value == dynamic.from(new_value) {
        True -> function.identity
        False -> do_computation
      }
    }
  }
}

pub fn guard(
  derivation: Store(data, computed),
  eff: fn(data, computed) -> Effect(msg),
) {
  let eff = eff(derivation.data, derivation.computed)
  add_effect(derivation, eff)
}

pub fn view(
  derivation: Store(data, computed),
  viewer: fn(data, computed) -> Element(msg),
) {
  viewer(derivation.data, derivation.computed)
}

fn add_effect(derivation: Store(data, computed), eff: Effect(msg)) {
  let effect = dynamic.from(eff)
  let effects = [effect, ..derivation.effects]
  Store(..derivation, effects:)
}

fn panic_if_different_computations_count(old_computations, computations) {
  let count = list.length(old_computations)
  use <- bool.guard(when: count == 0, return: Nil)
  let is_same_count = count == list.length(computations)
  use <- bool.guard(when: is_same_count, return: Nil)
  panic as "Memoized computed should be consistent over time, otherwise memo can not work."
}
