%%%-------------------------------------------------------------------
%%% @author johnleytondiaz
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 31. Jul 2017 11:08 AM
%%%-------------------------------------------------------------------
-module(test_controller).
-author("johnleytondiaz").

%% API
-export([init/2, task_end/3, task_list/0, prepare/5, process_done/1, documents/5]).

init(_Opts, _Workers) ->
  ok.

%% This function is mandatory in order for the status endpoint work, you can add additional validations
%% and/or executions on success and error, but must keep the first line, this function is not async, for
%% that reason if this one fails your task will get broke.
task_end(_Scheduler, {_Mod, _Function, [WorkerName, _Task, _StartDate, _EndDate, _Opts]}, {ok, _Result}) ->
  %% Next line is mandatory for status endpoint to work
  %%taskeduler_stats:set_status(WorkerName, last_run_task, Task),
  utils:inf("Success for ~p", [WorkerName]),
  ok;
task_end(_Scheduler, {_, _, [WorkerName, Task, _, _, _]}, {error, Error}) ->
  utils:inf("Error executing task ~p on worker ~p: ~p", [Task, WorkerName, Error]),
  %% Next line is mandatory for status endpoint to work
  %%taskeduler_stats:set_status(WorkerName, tasks_in_error, Task),
  ok.

task_list() ->
  [{1, <<"Cust 1">>}, {2, <<"Cust 2">>}, {4, <<"Cust 3">>}, {5, <<"Cust 4">>}].

%% This function is executed every time a worker starts doing sync
prepare(_WorkerName, _StartTime, _EndTime, _Type, _Opts) ->
  ok.

%% Do something on process exit
process_done(_WorkerName) ->
  ok.

documents(WorkerName, Task, StartTime, EndTime, Options) ->
  utils:inf("OPTS ~p, Worker ~p", [Options, WorkerName]),
  [tests, Task, StartTime, EndTime, []].