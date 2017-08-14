%%% @doc taskeduler_srv
%%%
%%% @author elpaisa
%%% @copyright (C) 2017, John L. Diaz
%%%
%%% @end
%%% Created : 09. Mar 2017 2:40 PM
%%%
-module(taskeduler_srv).
-author("elpaisa").
-behaviour(gen_server).
-define(SERVER, ?MODULE).

-include("taskeduler.hrl").

-ifdef(TEST).
-compile([export_all]).
-endif.


-export([start_link/1]).

%% server functions
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% Sync functions
-export([start/0, start/1, start/2, stop/1, stop/0, re_sync/0, re_sync/1, by_date/2, resume/1]).

%% Rest functions
-export([rest_call/4, rest_call/3, execute_rest_call/4]).

-record(state, {}).
%%==============================================================================
%% API functions
%%==============================================================================

start_link(ServiceContext) ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, _Args = [ServiceContext], []).

%%==============================================================================
%% gen_server callbacks
%%==============================================================================

%% @private
init([_ServiceContext]) ->
  utils:debug("initializing ~p", [?MODULE]),
  taskeduler_api:init(),
  {ok, #state{}}.


handle_call(_Request, _From, State) ->
  {noreply, ok, State}.
handle_cast({start, all}, State) ->
  taskeduler_api:start(),
  {noreply, State};
handle_cast({start_scheduler, Scheduler}, State) ->
  taskeduler_sync:start_scheduler(Scheduler),
  {noreply, State};
handle_cast({stop, all}, State) ->
  taskeduler_api:stop(),
  {noreply, State};
handle_cast({start, WorkerName}, State) ->
  taskeduler_api:sync_by(WorkerName),
  {noreply, State};
handle_cast({start, WorkerName, WorkerType}, State) ->
  taskeduler_api:sync_by(WorkerName, WorkerType),
  {noreply, State};
handle_cast({by_date, ModuleName, Date}, State) ->
  taskeduler_api:by_date(ModuleName, Date),
  {noreply, State};
handle_cast({resume, WorkerName}, State) ->
  taskeduler_api:resume(WorkerName),
  {noreply, State};
handle_cast({stop, WorkerName}, State) ->
  taskeduler_api:stop(WorkerName),
  {noreply, State};
handle_cast({re_sync, all}, State) ->
  taskeduler_api:re_sync(),
  {noreply, State};
handle_cast({re_sync, ModuleName}, State) ->
  taskeduler_api:re_sync(ModuleName),
  {noreply, State};
handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

start() ->
  [{
    gen_server:cast(?MODULE, {start, all}),
    async_message()
  }].
stop() ->
  gen_server:cast(?MODULE, {stop, all}).
start(WorkerName) ->
  [{
    gen_server:cast(?MODULE, {start, WorkerName}),
    async_message()
  }].
start(WorkerName, WorkType) ->
  [{
    gen_server:cast(?MODULE, {start, WorkerName, WorkType}),
    async_message()
  }].
resume(WorkerName) ->
  [{
    gen_server:cast(?MODULE, {resume, WorkerName}),
    async_message()
  }].
by_date(ModuleName, Date) ->
  [{
    gen_server:cast(?MODULE, {by_date, ModuleName, Date}),
    async_message()
  }].
stop(WorkerName) ->
  gen_server:cast(?MODULE, {stop, WorkerName}).
re_sync() ->
  [{
    gen_server:cast(?MODULE, {re_sync, all}),
    async_message()
  }].
re_sync(WorkerName) ->
  [{
    gen_server:cast(?MODULE, {re_sync, WorkerName}),
    async_message()
  }].

async_message() ->
  <<"Start signal sent, this is an async call, to follow up the sync status, please use 'status' endpoint">>.

%%
%% @doc Attempts to execute a call to the rest_handler module specified in the config file,
%% with the Path equivalent to a function, the function arity must be 2, [Param, Body | undefined, undefined]
%%
rest_call(Path, Param, Body) ->
  rest_call(Path, Param, Body, false).
rest_call(<<"async">>, Path, Param, Body) ->
  rest_call(Path, Param, Body, true),
  async_message();
rest_call(Path, Param, Body, IsAsync) ->
  Function = utils:need_atom(Path),
  Mod = taskeduler:get_env(rest_handler),
  Exec = {Mod, Function, Param, Body, IsAsync},
  is_valid(taskeduler_api:is_valid_call(Mod, Function, 2), Exec).

is_valid(false, _)->
  [{error, not_found}];
is_valid(true, {Mod, Function, Param, Body, IsAsync})->
  execute_rest_call(Mod, Function, [Param, Body], IsAsync).

execute_rest_call(Mod, Function, Params, _IsAsync) when _IsAsync =:= true ->
  erlang:apply(Mod, Function, Params),
  async_message();
execute_rest_call(Mod, Function, Params, _IsAsync) ->
  erlang:apply(Mod, Function, Params).