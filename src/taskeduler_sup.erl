%%%
%%% @doc taskeduler_sup
%%%
%%% taskeduler top-level supervisor
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
%%% @end
-module(taskeduler_sup).

-ifdef(TEST).
-compile([export_all]).
-endif.

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SUPERVISOR, ?MODULE).

%%==============================================================================
%% API functions
%%==============================================================================

start_link(ServiceContext) ->
  supervisor:start_link({local, ?SUPERVISOR}, ?MODULE, [ServiceContext]).


%%==============================================================================
%% Supervisor callbacks
%%==============================================================================

init([ServiceContext]) ->
  Server =
    {taskeduler_srv,
      {taskeduler_srv, start_link, [ServiceContext]},
      permanent, 5000, worker,
      dynamic % XXX
    },

  Children = [Server],

  {ok, {{one_for_one, 5, 10}, Children}}.
