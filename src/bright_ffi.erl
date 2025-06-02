-module(bright_ffi).

-export([coerce/1]).

% Due to deprecation of `dynamic.from`, bright defines its own coercion
% function to restore the dynamic capabibilies.
-spec coerce(A :: any()) -> any().
coerce(A) ->
  A.
