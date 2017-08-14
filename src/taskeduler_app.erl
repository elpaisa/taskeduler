%%% @doc Entry point of the API endpoints
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%% Created : 06. Mar 2017 3:51 PM
%%%
%%% @end

-module(taskeduler_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

-include("taskeduler.hrl").

%%
%% @doc Starts the app
%%
-spec start(term(), term()) -> ok.
start(_StartType, _StartArgs) ->
  do_start().

%%
%% @doc taskeduler application stop callback; unregisters the service
%%
-spec stop(term()) -> ok.
stop(_State) ->
  ServiceName = taskeduler:get_env(service_name, ?SERVICE_PREFIX),
  ok = taskeduler_service:remove_service({ServiceName, taskeduler_v1_http, []}),
  utils:inf("taskeduler application stopped", []),
  ok.

%%
%% @private registers the service and starts the supervision tree
%%
-spec do_start() -> ok.
do_start() ->
  utils:inf("starting taskeduler application...", []),
  ServiceName = taskeduler:get_env(service_name, ?SERVICE_PREFIX),
  taskeduler_service:add_service({ServiceName, taskeduler_v1_http, []}),
  %% start the supervisor
  Sup = taskeduler_sup:start_link(?SERVICE_CONTEXT),
  utils:inf("taskeduler application started", []),
  Sup.
