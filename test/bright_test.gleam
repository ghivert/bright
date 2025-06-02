import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

@external(javascript, "./bright.ffi.mjs", "areDependenciesEqual")
fn are_dependencies_equal(a: a, b: b) -> Bool {
  coerce(a) == coerce(b)
}

@external(erlang, "bright_ffi", "coerce")
@external(javascript, "./bright.ffi.mjs", "coerce")
fn coerce(a: a) -> b

// gleeunit test functions end in `_test`
pub fn int_equal_test() {
  let a = 1
  are_dependencies_equal(a, a) |> should.equal(True)
  are_dependencies_equal(a, 1) |> should.equal(True)
  are_dependencies_equal(a, 2) |> should.equal(False)
}

pub fn tuple_equal_test() {
  let a = #(2, 3)
  are_dependencies_equal(a, a) |> should.equal(True)
  are_dependencies_equal(a, #(2, 3)) |> should.equal(True)
  are_dependencies_equal(a, #(2, 5)) |> should.equal(False)
  are_dependencies_equal(a, #(2, 3, 4)) |> should.equal(False)
  are_dependencies_equal(a, #(3, 2)) |> should.equal(False)
  are_dependencies_equal(a, #(2, 4)) |> should.equal(False)
}

pub fn list_equal_test() {
  let a = [1, 2, 3]
  are_dependencies_equal(a, a) |> should.equal(True)
  are_dependencies_equal(a, [1, 2, 3]) |> should.equal(True)
  are_dependencies_equal(a, [1, 2, 0]) |> should.equal(False)
  are_dependencies_equal(a, [0, 2, 3]) |> should.equal(False)
  are_dependencies_equal(a, [1, 2]) |> should.equal(False)
  are_dependencies_equal(a, [1, 2, 3, 4]) |> should.equal(False)
  are_dependencies_equal(a, [1, 3, 2]) |> should.equal(False)
  are_dependencies_equal(a, []) |> should.equal(False)
}

pub fn nested_equal_test() {
  let a = [#(1, 2), #(3, 4), #(5, 6)]
  are_dependencies_equal(a, a) |> should.equal(True)
  are_dependencies_equal(a, [#(1, 2), #(3, 4), #(5, 6)]) |> should.equal(True)
  are_dependencies_equal(a, [#(1, 0), #(3, 4), #(5, 6)]) |> should.equal(False)
  are_dependencies_equal(a, [#(1, 2), #(3, 4), #(5, 0)]) |> should.equal(False)
  are_dependencies_equal(a, [#(1, 2), #(3, 4)]) |> should.equal(False)
  are_dependencies_equal(a, [#(1, 2), #(3, 4), #(5, 6), #(7, 8)])
  |> should.equal(False)
  are_dependencies_equal(a, []) |> should.equal(False)
}

pub type DummyTree(a) {
  Leaf
  Node(value: a, left: DummyTree(a), right: DummyTree(a))
}

pub fn tree_equal_test() {
  let a =
    Node(
      5,
      Node(3, Leaf, Leaf),
      Node(7, Leaf, Node(9, Node(8, Leaf, Leaf), Leaf)),
    )
  are_dependencies_equal(a, a) |> should.equal(True)
  are_dependencies_equal(
    a,
    Node(
      5,
      Node(3, Leaf, Leaf),
      Node(7, Leaf, Node(9, Node(8, Leaf, Leaf), Leaf)),
    ),
  )
  |> should.equal(True)
  are_dependencies_equal(a, Node(5, Node(3, Leaf, Leaf), Node(7, Leaf, Leaf)))
  |> should.equal(False)
  are_dependencies_equal(
    a,
    Node(
      5,
      Node(7, Leaf, Node(9, Node(8, Leaf, Leaf), Leaf)),
      Node(3, Leaf, Leaf),
    ),
  )
  |> should.equal(False)
}
