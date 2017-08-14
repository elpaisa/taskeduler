%%%
%%% @doc Distributed Erlang task scheduler with API
%%%
%%% This module can be included as a dependency in rebar.config
%%% All applications that use it as a dependency achieve highly
%%% distributed task scheduling capacity
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
%%% Created : 06. Mar 2017 3:51 PM
%%%
%%% @end
-module(taskeduler).

-define(APPLICATION, taskeduler).

-ifdef(TEST).
-compile(export_all).
-endif.

%% API
-export([start/0, stop/0]).
-export([get_env/1, get_env/2, set_env/2]).

-include("taskeduler.hrl").

%%==============================================================================
%% API functions
%%==============================================================================

%%
%% @doc starts the taskeduler application
%%
-spec start() -> ok.
start() ->
  {ok, Started} = application:ensure_all_started(?APPLICATION, permanent),
  utils:debug("started applications: ~p", [Started]),
  ok.

%%
%% @doc stops the taskeduler application
%%
-spec stop() -> ok.
stop() ->
  application:stop(?APPLICATION).

%%
%% @doc get an environment variable's value (or undefined if it doesn't exist)
%% @equiv get_env(Key, 'undefined')
%%
-spec get_env(atom()) -> term() | 'undefined'.
get_env(Key) ->
  get_env(Key, 'undefined').

%%
%% @doc get an environment variable's value (or Default if it doesn't exist)
%% @param Key name to search in config file
%% @param Default default value to return if Key is not found
%%
-spec get_env(atom(), term()) -> term().
get_env(Key, Default) ->
  application:get_env(?APPLICATION, Key, Default).

%%
%% @doc set the environment variable's value
%% @param Key name to set in the application variables
%% @param Value value to set in the application variables
%%
-spec set_env(atom(), any()) -> ok.
set_env(Key, Value) ->
  application:set_env(?APPLICATION, Key, Value).
