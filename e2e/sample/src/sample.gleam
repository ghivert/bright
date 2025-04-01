import bright.{type Bright}
import gleam/bool
import gleam/int
import gleam/io
import gleam/pair
import gleam/result
import gleam/string
import lustre
import lustre/effect
import lustre/event as e
import sketch
import sketch/css
import sketch/css/length.{px}
import sketch/lustre as sketch_
import sketch/lustre/element
import sketch/lustre/element/html as h
import styles

@external(javascript, "./sample.ffi.mjs", "dateNow")
fn now() -> Int {
  0
}

pub type State {
  State(counter: Int)
}

pub type Computed {
  Computed(double: Int, triple: Int, memoized: Int, last_lazy: Int)
}

pub type Model {
  Model(
    node: String,
    counter_1: Bright(State, Computed),
    counter_2: Bright(State, Computed),
  )
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
  let assert Ok(stylesheet) = sketch.stylesheet(strategy: sketch.Ephemeral)
  use _ <- result.try(start(stylesheet, update_one, "#single"))
  use _ <- result.try(start(stylesheet, update_both, "#double"))
  Ok(Nil)
}

fn start(stylesheet: sketch.StyleSheet, update, node: String) {
  lustre.application(init, update, view(_, stylesheet))
  |> lustre.start(node, node)
}

fn init(node: String) {
  let data = State(counter: 0)
  let computed = Computed(double: 0, triple: 0, memoized: 0, last_lazy: 0)
  let counter = bright.init(data, computed)
  #(Model(node:, counter_1: counter, counter_2: counter), effect.none())
}

/// Here, update both fields in `Model` with the Counter message.
/// Both counters are synchronized, both exebright the full lifecycle
/// and both side-effects run as desired.
fn update_both(model: Model, msg: Msg) {
  use counter_1 <- bright.step(update(model.counter_1, msg.counter))
  use counter_2 <- bright.step(update(model.counter_2, msg.counter))
  #(Model(..model, counter_1:, counter_2:), effect.none())
}

/// Here, update only one field, according to the main message.
/// The other message is not updated.
fn update_one(model: Model, msg: Msg) {
  let #(data, msg_) = select_data_structure(model, msg)
  use counter <- bright.step(update(data, msg_))
  case msg {
    First(..) -> #(Model(..model, counter_1: counter), effect.none())
    Second(..) -> #(Model(..model, counter_2: counter), effect.none())
  }
}

fn select_data_structure(model: Model, msg: Msg) {
  case msg {
    First(counter) -> #(model.counter_1, counter)
    Second(counter) -> #(model.counter_2, counter)
  }
}

/// Execute the full lifecycle, with derived data, and lazy computations.
fn update(model: Bright(State, Computed), msg: Counter) {
  use model <- bright.start(model)
  model
  |> bright.update(update_state(_, msg))
  |> bright.compute(fn(d, c) { Computed(..c, double: d.counter * 2) })
  |> bright.compute(fn(d, c) { Computed(..c, triple: d.counter * 3) })
  |> bright.lazy_compute(fn(d) { d.counter / 10 }, compute_memoized)
  |> bright.schedule(warn_on_three)
  |> bright.schedule(warn_on_three_multiple)
  |> bright.lazy_schedule(fn(d) { d.counter / 10 }, warn)
}

/// Raw update.
fn update_state(model: State, msg: Counter) {
  case msg {
    Decrement -> State(counter: model.counter - 1)
    Increment -> State(counter: model.counter + 1)
  }
  |> pair.new(effect.none())
}

fn view(model: Model, stylesheet: sketch.StyleSheet) {
  use <- sketch_.render(stylesheet, [sketch_.node()])
  element.fragment([
    navbar(model),
    styles.body([], [
      introduction(model.node),
      explanations(model.node),
      styles.container([], [
        counter(model.counter_1) |> element.map(First),
        counter(model.counter_2) |> element.map(Second),
      ]),
    ]),
    case model.node {
      "#double" -> element.none()
      _ -> styles.footer([], [h.text("Made with 💜 at Chou Corp.")])
    },
  ])
}

fn introduction(node) {
  case node {
    "#single" -> element.none()
    _ ->
      h.div(styles.intro(), [], [
        h.text("Bright is a Lustre's model & update management "),
        h.text("package. While your model is the only mutable "),
        h.text("place in your application, you can store almost "),
        h.text("everything you want inside. Bright provides an "),
        h.text("abstraction layer on top of Lustre's model, "),
        h.text("and add the ability to derive some data from "),
        h.text("your raw data, add some caching for extensive "),
        h.text("computations, and protects you from some "),
        h.text("invalid state that could come in sometimes."),
      ])
  }
}

fn explanations(node) {
  case node {
    "#single" ->
      css.class([css.compose(styles.intro()), css.margin_top(px(60))])
      |> h.div([], [
        styles.title("Dissociated counters"),
        h.text("That second example illustrates the ability to run two "),
        h.text("Bright counters in the same application, dissociated with "),
        h.text("each other. They both contains two computed, derived "),
        h.text("data, and one lazy data, computed every time the result "),
        h.text("of counter / 10 changes. But that time, when you change "),
        h.text("one, the other will stay the same. You can see the data "),
        h.text("and computations will not happen again. Open your "),
        h.text("console, and watch the side-effects running!"),
      ])
    _ ->
      h.div(styles.intro(), [], [
        styles.title("Synchronized counters"),
        h.text("That first example illustrates the ability to run two "),
        h.text("Bright counters in the same application, synchronized "),
        h.text("with each other. They both contains two computed, derived "),
        h.text("data, and one lazy data, computed every time the result"),
        h.text("of counter / 10 changes. Open your console, and watch "),
        h.text("the side-effects running!"),
      ])
  }
}

fn navbar(model: Model) {
  case model.node {
    "#single" -> element.none()
    _ -> styles.nav()
  }
}

fn counter(counter: Bright(State, Computed)) {
  let #(data, computed) = bright.unwrap(counter)
  styles.counter_wrapper([], [
    styles.counter([], [
      styles.counter_number(data.counter),
      styles.buttons_wrapper([], [
        styles.button([e.on_click(Increment)], [h.text("Increase")]),
        styles.button([e.on_click(Decrement)], [h.text("Decrease")]),
      ]),
    ]),
    styles.counter_infos([], [
      styles.computed("computed.last_lazy: ", computed.last_lazy),
      h.hr_([]),
      styles.computed("computed.double: ", computed.double),
      styles.computed("computed.triple: ", computed.triple),
    ]),
  ])
}

fn compute_memoized(state: State, computed: Computed, _e) {
  let memoized = state.counter * 1000
  let last_lazy = now()
  Computed(..computed, memoized:, last_lazy:)
}

fn warn_on_three(state: State, _: Computed) {
  use <- bool.guard(when: state.counter != 3, return: effect.none())
  use _ <- effect.from
  io.println("This message happened because the counter equals 3!")
}

fn warn_on_three_multiple(state: State, _: Computed) {
  use <- bool.guard(when: state.counter % 3 != 0, return: effect.none())
  use _ <- effect.from
  let counter = int.to_string(state.counter)
  let msg = "This message happened because the counter is a multiple of 3!"
  [msg, "(" <> counter <> ")"]
  |> string.join(" ")
  |> io.println
}

fn warn(_, _, _) {
  use _ <- effect.from
  "This lazy message happened because the result of counter / 10 changed value!"
  |> io.println
}
