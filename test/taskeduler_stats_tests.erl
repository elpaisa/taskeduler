%%% @hidden
%%% @doc taskeduler_stats_tests
%%
%%% taskeduler stats module tests
%%%
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
-module(taskeduler_stats_tests).

-ifdef(TEST).

-include("taskeduler.hrl").
-include("taskeduler_test.hrl").

-include_lib("eunit/include/eunit.hrl").


-import(taskeduler_stats, [status/0, status/1, set_status/3, set_status/1, save_status/1,
pos/1, push_metrics/3]).

-import(taskeduler_sync, [init/0, stop/0]).


setup() ->
  taskeduler:set_env(workers, get_test_workers()),
  {[]}.

teardown({Apps}) ->
  meck:unload(Apps),
  ok.


all_test_() ->
  {
    setup,
    fun setup/0,
    fun teardown/1,
    [
    ]
  }.


get_test_workers() ->
  [
    {incidents,
      [{requires_mapping, true}, {re_sync_days, 7}, {max_incident_fetch, 2000}],
      [{incidents_regular, 60, minutes}, {incidents_daily, 1, days}] %% Worker definitions
    }
  ].

-endif.