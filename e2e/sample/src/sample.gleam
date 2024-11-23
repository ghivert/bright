import gleam/int
import gleam/io
import gleam/pair
import lustre
import lustre/attribute as a
import lustre/effect
import lustre/element
import lustre/element/html as h
import lustre/event as e
import scart.{type Scart}

pub type Data {
  Data(counter: Int)
}

pub type Computed {
  Computed(double: Int, triple: Int, memoized: Int)
}

pub type Model {
  Model(counter_1: Scart(Data, Computed), counter_2: Scart(Data, Computed))
}

pub type Msg {
  First(counter: Counter)
  Second(counter: Counter)
}

pub type Counter {
  Decrement
  Increment
}

/// It's possible to switch between `update_both` and `update_one`
/// to see how it works actually.
pub fn main() {
  lustre.application(init, update_both, view)
  |> lustre.start("#app", Nil)
}

fn init(_: Nil) {
  let data = Data(counter: 0)
  let computed = Computed(double: 0, triple: 0, memoized: 0)
  let counter = scart.init(data, computed)
  scart.return(Model(counter_1: counter, counter_2: counter))
}

/// Here, update both fields in `Model` with the Counter message.
/// Both counters are synchronized, both execute the full lifecycle
/// and both side-effects run as desired.
fn update_both(model: Model, msg: Msg) {
  use counter_1 <- scart.step(update(model.counter_1, msg.counter))
  use counter_2 <- scart.step(update(model.counter_2, msg.counter))
  scart.return(Model(counter_1:, counter_2:))
}

/// Here, update only one field, according to the main message.
/// The other message is not updated.
fn update_one(model: Model, msg: Msg) {
  let #(data, msg_) = select_data_structure(model, msg)
  use counter <- scart.step(update(data, msg_))
  case msg {
    First(..) -> scart.return(Model(..model, counter_1: counter))
    Second(..) -> scart.return(Model(..model, counter_2: counter))
  }
}

/// Could be inlined, it's just more readable in my opinion.
fn select_data_structure(model: Model, msg: Msg) {
  case msg {
    First(counter) -> #(model.counter_1, counter)
    Second(counter) -> #(model.counter_1, counter)
  }
}

/// Execute the full lifecycle, with derived data, and lazy computations.
fn update(model: Scart(Data, Computed), msg: Counter) {
  use model <- scart.update(model, update_data(_, msg))
  model
  |> scart.compute(fn(d, c) { Computed(..c, double: d.counter * 2) })
  |> scart.compute(fn(d, c) { Computed(..c, triple: d.counter * 3) })
  |> scart.lazy_compute(fn(d) { d.counter / 10 }, compute_memoized)
  |> scart.guard(warn_on_three)
  |> scart.guard(warn_on_three_multiple)
  |> scart.lazy_guard(fn(d) { d.counter / 10 }, warn)
}

/// Raw update.
fn update_data(model: Data, msg: Counter) {
  case msg {
    Decrement -> Data(counter: model.counter - 1)
    Increment -> Data(counter: model.counter + 1)
  }
  |> pair.new(effect.none())
}

fn view(model: Model) {
  h.div([a.style([#("display", "flex")])], [
    counter(model.counter_1) |> element.map(First),
    counter(model.counter_2) |> element.map(Second),
  ])
}

fn counter(counter: Scart(Data, Computed)) {
  use data, derived <- scart.view(counter)
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
