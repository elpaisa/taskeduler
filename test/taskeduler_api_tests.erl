%%% @hidden
%%% @doc taskeduler_api_tests
%%%
%%% taskeduler Erlang API unit tests
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
-module(taskeduler_api_tests).

-ifdef(TEST).
-compile([export_all]).

-include("taskeduler.hrl").
-include("taskeduler_test.hrl").

-include_lib("eunit/include/eunit.hrl").


-import(taskeduler_api, [init/0, status/0, status/1, start/0, stop/1,
re_sync/0, re_sync/1, re_sync/2, by_date/2, resume/1, sync_by/1, sync_by/2, stop/0,
is_valid_call/3, is_exported/3]).

setup() ->
  taskeduler:set_env(controller_module, test_controller),
  taskeduler_cache:insert(?WORKERS_TABLE, {taskeduler_worker_names, []}),
  taskeduler:set_env(workers, ?TEST_WORKERS),
  {[]}.

teardown(_) ->
  ok.

all_test_() ->
  {
    setup,
    fun setup/0,
    fun teardown/1,
    [
      {"api", {timeout, ?TEST_TIMEOUT, fun test_api/0}}
    ]
  }.

test_api() ->
  init(),
  [{status,
    [{workers,
      [{Worker1,
        [{module,
          [{name, ModName}, _]}, _,
          {status,
            [_,
              {status, Status1},
              _, _, _, _, _, _, _, _, _,
              _, _, _, _, _, _, _]}]},
        {Worker2, _}]
    }]
  }] = status(),
  [
    ?assertEqual(
      ok, init()
    ),
    ?assertEqual(
      test_regular, Worker1
    ),
    ?assertEqual(
      test_daily, Worker2
    ),
    ?assertEqual(
      waiting, Status1
    ),
    ?assertEqual(
      test_controller, ModName
    ),
    ?assertEqual(
      [{status, [{error,<<"No worker info, has it run?">>}]}], status(test_wrong)
    ),
    ?assertEqual(
      [{ok, all_services_started}], start()
    ),
    ?assert(
      is_pid(whereis(test_daily))
    ),
    ?assert(
      is_pid(whereis(test_regular))
    ),
    ?assertEqual(
      [{ok, service_stopped}, {process, test_regular}],
      stop(test_regular)
    ),
    ?assertEqual(
      undefined,
      whereis(test_regular)
    ),
    ?assertEqual(
      [{ok, service_stopped}, {process, test_daily}],
      stop(test_daily)
    ),
    ?assertEqual(
      undefined,
      whereis(test_daily)
    ),
    ?assertEqual(
      [{test_controller_re_sync,
        {test_controller,
          [{requires_mapping, true},
            {re_sync_days, 7},
            {max_test_fetch, 2000}]},
        {1, days}}],
      re_sync()
    ),
    ?assertEqual(
      {test_controller_re_sync,
        {test_controller,
          [{requires_mapping, true},
            {re_sync_days, 7},
            {max_test_fetch, 2000}]},
        {1, days}},
      re_sync(test_controller)
    ),
    ?assertEqual(
      {test_daily_resync,
        {test_controller,
          [{requires_mapping, true},
            {re_sync_days, 7},
            {max_test_fetch, 2000}]},
        {1, days}
      },
      re_sync(test_daily_resync, {test_controller, ?TEST_OPTS, []})
    ),
    ?assertEqual(
      {test_controller_by_date_2017_05_02,
        {test_controller,
          [{requires_mapping, true},
            {re_sync_days, 7},
            {max_test_fetch, 2000}]},
        {1, days}},
      by_date(test_controller, <<"2017-05-02">>)
    ),
    ?assertEqual(
      ok,
      resume(test_daily)
    ),
    ?assertEqual(
      [{ok, sync_started},
        {worker, test_daily},
        {options, [{requires_mapping, true},
          {re_sync_days, 7},
          {max_test_fetch, 2000}]}],
      sync_by(test_daily)
    ),
    ?assertEqual(
      [{error, invalid_worker}, {test_daily, do_sync}],
      sync_by(test_daily, do_sync)
    ),
    ?assertEqual(
      [{ok, sync_started},
        {worker, test_daily},
        {options, [{requires_mapping, true},
          {re_sync_days, 7},
          {max_test_fetch, 2000}]}],
      sync_by(test_daily, do_work)
    ),
    ?assertEqual(
      [[[{ok, nothing_to_stop}],
        [{ok, service_stopped}, {process, test_daily}]]],
      stop()
    ),
    ?assertEqual(
      false,
      is_valid_call(test_controller, stop, 0)
    ),
    ?assertEqual(
      true,
      is_valid_call(test_controller, task_list, 0)
    ),
    ?assertEqual(
      true,
      is_exported([{documents, 5}], documents, 5)
    ),
    ?assertEqual(
      false,
      is_exported([{documents, 4}], documents, 5)
    )
  ].

-endif.