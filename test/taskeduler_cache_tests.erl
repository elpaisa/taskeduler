%%% @hidden
%%% @doc taskeduler_sync_tests
%%%
%%% taskeduler sync module tests
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%% @end
-module(taskeduler_cache_tests).

-ifdef(TEST).

-include("taskeduler.hrl").
-include("taskeduler_test.hrl").

-include_lib("eunit/include/eunit.hrl").

-export([hello/0]).

-import(taskeduler_cache, [cache_worker/5, insert/2,
set_ets/1, get/2, get/3, take/2, take/3, insert/3, update/3, sum/4]).
-import(taskeduler_stats, [status/0]).

setup() ->
  taskeduler:set_env(workers, get_test_workers()),
  meck:expect(taskeduler_stats, set_status, fun(_WorkerName, _Key, _Value) ->
    ok end),
  meck:expect(gascheduler, start_link, fun(_Scheduler, _Nodes, _Client, _MaxWorkers, _MaxRetries) ->
    {ok, c:pid(0, 250, 0)} end),
  meck:expect(gascheduler, execute, fun(_, _) ->
    ok end),
  {[gascheduler, taskeduler_stats]}.

teardown({Apps}) ->
  meck:unload(Apps),
  ok.


all_test_() ->
  {
    setup,
    fun setup/0,
    fun teardown/1,
    [
      {"stats", {timeout, ?TEST_TIMEOUT, fun test_stats/0}},
      {"other", {timeout, ?TEST_TIMEOUT, fun test_other/0}}
    ]
  }.

test_stats() ->
  insert(?WORKERS_TABLE, {taskeduler_worker_names, [incidents_regular]}),
  cache_worker(incidents_regular, incidents, 60, minutes, incident_opts()),
  {_, [IncidentsRegular | _]} = lists:keyfind(workers, 1, status()),
  {WorkerName, [
    {module, [
      {name, ModuleName},
      _
    ]},
    _,
    {StatusKey, _}
  ]} = IncidentsRegular,
  [
    ?assertEqual(incidents_regular, WorkerName),
    ?assertEqual(incidents, ModuleName),
    ?assertEqual(status, StatusKey)
  ].


test_other() ->
  ETS = set_ets(test),
  {ok, _E, Result} = insert(test, {1, any}),
  {ok, _E2, [Get]} = get(test, 1),
  [
    ?assertEqual(test, ETS),
    ?assertEqual(true, Result),
    ?assertEqual({1, any}, Get)
  ].

incident_opts() ->
  [{requires_mapping, true}, {re_sync_days, 7}, {max_incident_fetch, 2000}].

hello() ->
  utils:inf("Cache Tests are working", []).

get_test_workers() ->
  [
    {incidents,
      [{requires_mapping, true}, {re_sync_days, 7}, {max_incident_fetch, 2000}],
      [{incidents_regular, 60, minutes}, {incidents_daily, 1, days}] %% Worker definitions
    }
  ].

-endif.