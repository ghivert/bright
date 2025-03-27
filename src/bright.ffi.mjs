import * as gleam from "./gleam.mjs"

/** Special shortcut to gain speed when comparing to identical data between
 * rerenders. If the two data are the same (same object), comparison should be
 * done directly on references. If they're arrays (tuples in Gleam), user wanted
 * to provide multiple references, like hooks in React. In this case, check
 * every member reference equality with the previous render. Otherwise, use the
 * Gleam comparison (objects can be different referentially, but be the same
 * with structural comparison).
 * Not used in Erlang, because BEAM does not support references equality like
 * JavaScript. */
export function areDependenciesEqual(a, b) {
  // Referential equality.
  if (a === b) return true
  if (areTupleMembersReferentiallyEquals(a, b)) return true
  return gleam.isEqual(a, b)
}

/** Accepts two data structures, and ensures they're both Gleam tuples, and
 * perform a light comparison between references. If at least one data references
 * in the tuples are different, give back hand to gleam.isEqual. */
function areTupleMembersReferentiallyEquals(a, b) {
  if (!Array.isArray(a)) return false
  if (!Array.isArray(b)) return false
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++)
    // Referential equality.
    if (a[i] !== b[i]) return false
  return true
}
