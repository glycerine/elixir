% Holds implementation for most Module::Behavior methods.
-module(elixir_module_behavior).
-export([is_module/1, module_name/1, module/1, mixins/1, data/1, builtin_mixin/1,
  get_ivar/2, set_ivar/3, set_ivars/2, update_ivar/3, update_ivar/4]).
-include("elixir.hrl").

% Introspection

module_name(#elixir_slate__{module=Module})  -> ?ELIXIR_EX_MODULE(Module);
module_name(#elixir_object__{name=Module})   -> ?ELIXIR_EX_MODULE(Module);
module_name(Native) -> ?ELIXIR_EX_MODULE(builtin_mixin(Native)).

is_module(#elixir_object__{}) -> true;
is_module(_) -> false.

module(#elixir_object__{} = Self) -> Self;
module(Else) -> elixir_constants:lookup(module_name(Else)).

mixins(#elixir_object__{data=Data}) when is_atom(Data) ->
  try
    ets:lookup_element(Data, mixins, 2)
  catch
    error:badarg -> []
  end;

mixins(#elixir_object__{name=Name}) ->
  Name:'__elixir_mixins__'();

mixins(Native) -> % TODO: This needs to be properly tested.
  [module_name(Native),'Module::Methods'].

data(#elixir_slate__{data=Data}) ->
  Data;

data(#elixir_object__{data=Data}) when not is_atom(Data) ->
  Data;

data(#elixir_object__{data=Data}) ->
  try
    ets:lookup_element(Data, data, 2)
  catch
    error:badarg -> orddict:new()
  end;

data(Native) ->
  orddict:new(). % Native types has no data.

%% ivars

get_ivar(Self, Name) when is_atom(Name) ->
  elixir_helpers:orddict_find(Name, data(Self));

get_ivar(Self, Name) ->
  elixir_errors:error({badivar, Name}).

set_ivar(Self, Name, Value) when is_atom(Name) ->
  set_ivar_dict(Self, Name, set_ivar, fun(Dict) -> orddict:store(Name, Value, Dict) end).

set_ivars(Self, Value) ->
  assert_dict_with_atoms(Value),
  set_ivar_dict(Self, elixir, set_ivars, fun(Dict) -> elixir_helpers:orddict_merge(Dict, element(2, Value)) end).

update_ivar(Self, Name, Function) ->
  set_ivar_dict(Self, Name, update_ivar, fun(Dict) -> orddict:update(Name, Function, Dict) end).

update_ivar(Self, Name, Initial, Function) ->
  set_ivar_dict(Self, Name, update_ivar, fun(Dict) -> orddict:update(Name, Function, Initial, Dict) end).

set_ivar_dict(_, Name, _, _) when not is_atom(Name) ->
  elixir_errors:error({badivar, Name});

set_ivar_dict(#elixir_slate__{data=Dict} = Self, Name, _, Function) ->
  Self#elixir_slate__{data=Function(Dict)};

set_ivar_dict(#elixir_object__{data=Dict} = Self, Name, _, Function) when not is_atom(Dict) ->
  Self#elixir_object__{data=Function(Dict)};

set_ivar_dict(#elixir_object__{data=Data} = Self, Name, _, Function) ->
  Dict = ets:lookup_element(Data, data, 2),
  Object = Self#elixir_object__{data=Function(Dict)},
  ets:insert(Data, { data, Object#elixir_object__.data }),
  Object;

set_ivar_dict(Self, _, Method, _) ->
  builtinnotallowed(Self, Method).

assert_dict_with_atoms(#elixir_orddict__{struct=Dict} = Object) ->
  case lists:all(fun is_atom/1, orddict:fetch_keys(Dict)) of
    true  -> Dict;
    false ->
      elixir_errors:error({badivars, Object})
  end;

assert_dict_with_atoms(Data) ->
  elixir_errors:error({badivars, Data}).

% Raise builtinnotallowed error with the given reason:
builtinnotallowed(Builtin, Reason) ->
  elixir_errors:error({builtinnotallowed, {Reason, Builtin}}).

% Builtin mixins

builtin_mixin(Native) when is_list(Native) ->
  'exList::Behavior';

builtin_mixin(Native) when is_binary(Native) ->
  'exString::Behavior';

builtin_mixin(Native) when is_integer(Native) ->
  'exInteger::Behavior';

builtin_mixin(Native) when is_float(Native) ->
  'exFloat::Behavior';

builtin_mixin(Native) when is_atom(Native) ->
  'exAtom::Behavior';

builtin_mixin(#elixir_orddict__{}) ->
  'exOrderedDict::Behavior';

builtin_mixin(Native) when is_bitstring(Native) ->
  'exBitString::Behavior';

builtin_mixin(Native) when is_tuple(Native) ->
  'exTuple::Behavior';

builtin_mixin(Native) when is_function(Native) ->
  'exFunction::Behavior';

builtin_mixin(Native) when is_pid(Native) ->
  'exProcess::Behavior';

builtin_mixin(Native) when is_reference(Native) ->
  'exReference::Behavior';

builtin_mixin(Native) when is_port(Native) ->
  'exPort::Behavior'.