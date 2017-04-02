%%%-------------------------------------------------------------------
%%% @doc
%%% Utility module to create supervisor and worker specs.
%%% @end
%%%-------------------------------------------------------------------
-module(ebus_supervisor_spec).

%% API
-export([supervise/2]).
-export([supervisor/2, supervisor/3]).
-export([worker/2, worker/3]).

%%%===================================================================
%%% API functions
%%%===================================================================

%% @doc
%% Receives a list of children (workers or supervisors) to
%% supervise and a set of options. Returns a tuple containing
%% the supervisor specification.
%%
%% Example:
%%
%% ```
%% ebus_supervisor_spec:supervise(Children, #{strategy => one_for_one}).
%% '''
%% @end
-spec supervise(
  [supervisor:child_spec()], supervisor:sup_flags()
) -> {ok, tuple()}.
supervise(Children, SupFlags) ->
  assert_unique_ids([Id || #{id := Id} <- Children]),
  {ok, {sup_flags(SupFlags), Children}}.

%% @equiv supervisor(Module, Args, [])
supervisor(Module, Args) ->
  supervisor(Module, Args, #{}).

%% @doc
%% Defines the given `Module' as a supervisor which will be started
%% with the given arguments.
%%
%% Example:
%%
%% ```
%% ebus_supervisor_spec:supervisor(my_sup, [], #{restart => permanent}).
%% '''
%%
%% By default, the function `start_link' is invoked on the given
%% module. Overall, the default values for the options are:
%%
%% ```
%% #{
%%   id       => Module,
%%   start    => {Module, start_link, Args},
%%   restart  => permanent,
%%   shutdown => infinity,
%%   modules  => [module]
%% }
%% '''
%% @end
-spec supervisor(
  module(), [term()], supervisor:child_spec()
) -> supervisor:child_spec().
supervisor(Module, Args, Spec) when is_map(Spec) ->
  child(supervisor, Module, Args, Spec#{shutdown => infinity});
supervisor(_, _, _) -> throw(invalid_child_spec).

%% @equiv worker(Module, Args, [])
worker(Module, Args) ->
  worker(Module, Args, #{}).

%% @doc
%% Defines the given `Module' as a worker which will be started
%% with the given arguments.
%%
%% Example:
%%
%% ```
%% ebus_supervisor_spec:worker(my_module, [], #{restart => permanent}).
%% '''
%%
%% By default, the function `start_link' is invoked on the given
%% module. Overall, the default values for the options are:
%%
%% ```
%% #{
%%   id       => Module,
%%   start    => {Module, start_link, Args},
%%   restart  => permanent,
%%   shutdown => 5000,
%%   modules  => [module]
%% }
%% '''
%% @end
-spec worker(
  module(), [term()], supervisor:child_spec()
) -> supervisor:child_spec().
worker(Module, Args, Spec) when is_map(Spec) ->
  child(worker, Module, Args, Spec);
worker(_, _, _) -> throw(invalid_child_spec).

%%%===================================================================
%%% Internal functions
%%%===================================================================

%% @private
assert_unique_ids([]) ->
  ok;
assert_unique_ids([Id | Rest]) ->
  case lists:member(Id, Rest) of
    true -> throw({badarg, duplicated_id});
    _    -> assert_unique_ids(Rest)
  end.

%% @private
child(Type, Module, Args, Spec) when is_map(Spec) ->
    Rel = erlang:system_info(compat_rel),
    Id       = maps:get(id, Spec, Module),
    Start    = maps:get(start, Spec, {Module, start_link, Args}),
    Restart  = maps:get(restart, Spec, permanent),
    Shutdown = maps:get(shutdown, Spec, 5000),
    Modules  = maps:get(modules, Spec, [Module]),
    if Rel =< 17 ->
	    {
	      Id,
	      Start,
	      Restart,
	      Shutdown,
	      Type,
	      Modules };
       true ->
	    #{ id       => Id,
	       start    => Start,
	       restart  => Restart,
	       shutdown => Shutdown,
	       type     => Type,
	       modules  => Modules
	     }
    end.

-spec sup_flags(Map::supervisor:sup_flags()) -> supervisor:sup_flags().

sup_flags(Map) ->
    Rel = erlang:system_info(compat_rel),
    if Rel =< 17 ->
	    {maps:get(strategy, Map, one_for_one),
	     maps:get(intensity,Map, 1),
	     maps:get(period, Map, 5)};
       true ->
	    Map
    end.
