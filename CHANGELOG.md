## v1.0.1 - 2025-05-22

- Deprecate `bright.unwrap` to favour `bright.state` & `bright.computed`, and
  avoid overhead of tuple creation. By being simple, it helps in function
  inlining, and it also make sure there's only one way to get data from bright.

## v1.0.0 — 2025-04-01

- Release first version of Bright!
- Bright supports `state` & `computed`, as well as managing side-effects.
- Bright has been tested in production on both target before that release, and
  is now stable enough to be released in the wild!

Thanks to [@Adele-Desmazieres](https://github.com/Adele-Desmazieres/) for the bugfix and her first contribution!
