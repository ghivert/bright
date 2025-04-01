# Bright

Bright is a library to help you manage your `model` and your `update` function in
a [Lustre](https://lustre.build) application. As you probably know, in Lustre,
your model is the only mutable place of the application, and centralize every
data your application uses. If you're coming from the JS world, it can seems
weird at first, because it's usual to have multiple storage places in an
application, whether they're contexts, stores, observables, or anything else.

In such a centralized model, everything is simpler, and just works. However,
managing your model and your updates can quickly become a mess, with dependent
data, data splitting, normalization, etc. Bright comes in to help you avoid such
states, by both helping your to maintain a properly defined model, but also
to define dependant data in an easy way. Bright also provides a powerful caching
system to guarantee to not compute the same information twice!

> As usual, a demo is worth a thousand words, so take a look at
> [https://bright.chouquette.dev](https://bright.chouquette.dev)!

If you're used to stores & data management, you can skip the next section, see
you in the [getting started](#getting-started)!

## Installation

```sh
gleam add bright
```

## Dependent data? Caching system?

To sum up simply, a data is dependent on another data when the latter data is
required to compute the former. If you have worked with relational data, you
already encountered it. Let's take an example.

Imagine you have a list of users on one side, with their info (name, age for example)
and ID, and you have a list of addresses referring to a user by their ID. You want to
create a page displaying the user info and all of their addresses.
Intuitively, you would display the user info, and then you would find all the user
addresses in the address list to display them.

```gleam
pub type User {
  User(
    name: String,
    age: Int,
    id: String
  )
}

pub type Address {
  Address(
    street: String,
    city: String,
    country: String,
    user_id: String
  )
}

pub fn display_user_page(model, user_id) {
  // First find the user.
  use user <- result.try(list.find(model.users, fn (user) { user.id == user_id }))
  // After the user has been found, filter the addresses to find them.
  use addresses <- list.filter(model.addresses, fn (address) { address.user_id == user.id })
  // Do the display here.
}
```

While it works perfectly in this example, what if every time you need to access
those data? Recompute the same data over and over again, in every part of the
application? We can do better: define the user and its address in one record,
and use it everywhere!

```gleam
pub type UserAndAddress {
  UserAndAddress(
    user: User,
    addresses: List(Address)
  )
}

// Compute the data, and store it in your model.
pub fn compute_user_address(model) {
  list.map(model.users, fn (user) {
    let addresses = list.filter(model.addresses, fn (address) { address.user_id == user.id })
    UserAndAddresses(user:, addresses:)
  })
}

// The data is in your model.
pub fn display_user_page(model, user_id) {
  // Find directly everything!
  use UserAndAddress(user:, addresses:) <- result.try({
    list.find(model.users_and_addresses, fn (user) { user.id == user_id })
  })
  // Do the display here.
}
```

You have defined here a derived, computed data that depends on two previous data
you own. Now, every time you need to access the user, you have the address bundled!
But in a classic application, you would have to define that computation by yourself,
and make sure to keep it in sync after each update. That's where Bright comes in,
and do the hard work for you! Instead of having to think to synchronize the data
when a new data comes in, let Bright does it for you. And with built-in caching
on-demand, Bright will never recompute the same data twice for intense computations.

## Getting Started

Bright handles the hard task of computing the derived data when needed, and as
such, you have to initialize it at first. Bright accepts two types of data:
your main model, holding the raw data, and your derived, computed data. Because
Gleam is strongly-typed language, you'll have to define those data by hand.
A counter will be used to illustrate how to use it.

```gleam
/// Define your raw data. No derived data will reside here.
pub type State {
  State(counter: Int)
}

/// Define your derived data. No raw data will reside here.
pub type Computed {
  Computed(double: Int)
}

/// Define an alias, to simplify reference to the model.
pub type Model =
  Bright(State, Computed)

// In your init function, you'll initialize Bright. You can use it as-is as a
// replacement for your model.
pub fn init() {
  let state = State(counter: 0)
  let computed = Computed(double: 0)
  let model = bright.init(state, computed)
  #(model, effect.none())
}
```

Once Bright is initialized, you have to modify a bit your update function. Now,
instead of simply receiving the message and modifying your model, you'll have to
run that modification through Bright. You can then chain your computation calls
to the Bright object. And of course, derived data can be computed from pre-computed
derived data!

All bright functions are thought to work with `#(Bright(state, computed), Effect(msg))`
data, to work nicely with Lustre while staying type-safe. `bright.start` launch
the update cycle, and then, you can chain as much computations as you want!

```gleam
pub type Msg {
  Increment
  Decrement
}

pub fn update(model: Model, msg: Msg) {
  // bright.start begins the bright update cycle. Always use bright.start,
  // because start takes cares of lazy computations and cleanup.
  use model <- bright.start(model)
  // We can now chain computations on our #(Bright(state, computed), Effect(msg))
  // data newly created.
  model
  // By using function capture, we can easily use our update function here.
  // bright.update will automatically run your update against data, here our
  // Data record. Like every update function, that function have to return
  // a #(State, Effect(Msg)). The message will automatically be batched with
  // next messages.
  // Finally, #(Bright(State, Computed), Effect(msg)) is returned, with State
  // updated. To let you continue the chain.
  |> bright.update(update_state(_, msg))
  // bright.compute will compute the new derived data, and let you set it in
  // the computed. You can also simply return the original computed, in which
  // case the data is not updated.
  |> bright.compute(fn(state, computed) { Computed(..computed, double: state.counter * 2) })
  // bright.lazy_compute will compute the new derived data, if and only if the
  // selector you pass as the first argument changed between two renders.
  // In case the selector did not change, the old data is kept in memory for the
  // next render. When the compute function runs, state, computed and the result
  // of the selector are provided to the function.
  |> bright.lazy_compute(
    // That selector value is compared at every render.
    fn (state) { state.counter / 10 },
    // _counter is equal to state.counter / 10.
    fn(state, computed, _counter) { Computed(..computed, double: state.counter * 2) }
  )
}

pub fn update_state(state: State, msg: Msg) {
  case msg {
    Increment -> #(State(..state, counter: state.counter + 1), effect.none())
    Decrement -> #(State(..state, counter: state.counter - 1), effect.none())
  }
}
```

And once your data is computed, all you have to do is to run through your view
function!

```gleam
pub fn view(model: Model) {
  let #(state, computed) = bright.unwrap(model)
  // You can use state & computed with correct, up to date data.
  html.div([], [])
}
```

And you're good to go! Now, you don't have to think anymore to update your
derived data, everything is kept in-sync directly for you!

## Scheduling side-effects

Sometimes, you also have to define side-effects that run after your computations
have run. Because you figure out the data is finally incorrect. Or because your
user have written a false URL in the address bar. Bright got you covered too!
Just use `bright.schedule`, and let the side-effects flow automatically in your
app, only when you need it!

```gleam
pub fn update(model: Model, msg: Msg) {
  use model <- bright.update(model, update_state(_, msg))
  model
  |> bright.compute(fn(state, computed) { Computed(..computed, double: state.counter * 2) })
  |> bright.lazy_compute(
    fn (state) { state.counter / 10 },
    fn(state, computed) { Computed(..computed, double: state.counter * 2) }
  )
  // bright.schedule will run at every render, and let you the possibility to issue
  // a side-effect. Bright will take care to gather them, and provide them to the
  // runtime!
  |> bright.schedule(fn (state, computed) {
    effect.from(fn (dispatch) {
      io.println("That side-effect will run at every render!")
    })
  })
  // bright.lazy_schedule will issue the side-effect, if and only if the
  // selector you pass as the first argument changed between two renders.
  // In case the selector did not change, the old data is kept in memory for the
  // next render. When the compute function runs, state, computed and the result
  // of the selector are provided to the function.
  |> bright.lazy_schedule(
    fn (state) { state.counter / 10 },
    // _counter is equal to state.counter / 10.
    fn (state, computed, _counter) {
      effect.from(fn (dispatch) {
        io.println("That side-effect will only run when the selector changes!")
      })
    }
  )
}
```

## Combining multiple Bright

Sometimes, you also need to combine multiple Bright in the same model. While you
can keep a `Bright` as model, you could want to combine them, to handle one `Bright`
by page for example. `bright.step` helps you to do this.

```gleam
pub type Model {
  Model(
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

/// Here, we define a new update function, that calls our previously defined
/// update function. It keeps the two Bright synchronized by running the full
/// updated cycle on each of them.
/// Every effects are gathered during computations, and you can even issue
/// messages at the end of the update cycle, before returning your model.
fn update_both_counters(model: Model, msg: Msg) {
  use counter_1 <- bright.step(update(model.counter_1, msg.counter))
  use counter_2 <- bright.step(update(model.counter_2, msg.counter))
  #(Model(..model, counter_1:, counter_2:), effect.none())
}
```
