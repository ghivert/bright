import gleam/int
import gleam/io
import gleam/pair
import lustre
import lustre/effect
import lustre/element/html as h
import lustre/event as e
import scart.{type Scart}

pub type Data {
  Data(counter: Int)
}

pub type Computed {
  Computed(double: Int, triple: Int, memoized: Int)
}

pub type Model =
  Scart(Data, Computed)

pub type Msg {
  Decrement
  Increment
}

pub fn main() {
  lustre.application(init, lifecycle, view)
  |> lustre.start("#app", Nil)
}

pub fn init(_: Nil) {
  let data = Data(counter: 0)
  let computed = Computed(double: 0, triple: 0, memoized: 0)
  scart.init(data, computed)
  |> pair.new(effect.none())
}

pub fn lifecycle(model: Model, msg: Msg) {
  use model <- scart.update(model, update(_, msg))
  model
  |> scart.compute(fn(d, c) { Computed(..c, double: d.counter * 2) })
  |> scart.compute(fn(d, c) { Computed(..c, triple: d.counter * 3) })
  |> scart.lazy_compute(fn(d) { d.counter / 10 }, compute_memoized)
  |> scart.guard(warn_on_three)
  |> scart.guard(warn_on_three_multiple)
  |> scart.lazy_guard(fn(d) { d.counter / 10 }, warn)
}

pub fn update(model: Data, msg: Msg) {
  case msg {
    Decrement -> Data(counter: model.counter - 1)
    Increment -> Data(counter: model.counter + 1)
  }
  |> pair.new(effect.none())
}

pub fn view(model: Model) {
  use data, derived <- scart.view(model)
  h.div([], [
    h.button([e.on_click(Decrement)], [h.text("-")]),
    h.div([], [h.text(int.to_string(data.counter))]),
    h.div([], [h.text(int.to_string(derived.double))]),
    h.div([], [h.text(int.to_string(derived.triple))]),
    h.button([e.on_click(Increment)], [h.text("+")]),
  ])
}

fn compute_memoized(data: Data, computed: Computed) {
  let memoized = data.counter * 1000
  Computed(..computed, memoized:)
}

fn warn_on_three(data: Data, _: Computed) {
  case data.counter {
    3 -> effect.from(fn(_) { io.println("Three") })
    _ -> effect.none()
  }
}

fn warn_on_three_multiple(data: Data, _: Computed) {
  case data.counter % 3 {
    0 -> effect.from(fn(_) { io.println("Multiple") })
    _ -> effect.none()
  }
}

fn warn(_, _) {
  use _ <- effect.from
  io.println("Warning")
}
