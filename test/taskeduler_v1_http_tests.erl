%%% @hidden
%%% @doc taskeduler_v1_http_tests
%%%
%%% taskeduler HTTP API unit tests
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%% @end
-module(taskeduler_v1_http_tests).

-ifdef(TEST).
-compile({no_auto_import, [put/2]}).

-include("taskeduler.hrl").
-include("taskeduler_test.hrl").

-include_lib("eunit/include/eunit.hrl").

-import(taskeduler_v1_http, [
get/2, post/2, put/2, delete/2, head/2, generic_call/2, make_ok_response/2, required_permission/3]).


setup() ->
  meck:new(taskeduler_api, [passthrough]),
  meck:expect(taskeduler_api, start, fun() -> [{ok, all_services_started}] end),
  meck:expect(taskeduler_api, status, fun() -> [{status, [{worker_name, test}]}] end),
  meck:expect(taskeduler_api, sync_by, fun(_WorkerName) ->
    [{ok, sync_started}, {worker, _WorkerName}, {options, []}] end),
  {[taskeduler_api]}.

teardown({Apps}) ->
  meck:unload(Apps),
  ok.


all_test_() ->
  {
    setup,
    fun setup/0,
    fun teardown/1,
    [
      {"get", {timeout, ?TEST_TIMEOUT, fun test_get/0}}
    ]
  }.


test_get() ->
  [
    ?assertEqual(
      generic_response([{status, [{worker_name, test}]}], []),
      get([<<"status">>], [])
    ),
    ?assertEqual(
      generic_response(async_message(), []),
      get([<<"start">>], [])
    ),
    ?assertEqual(
      generic_response(async_message(), []),
      get([<<"start">>, <<"incidents_daily">>], [])
    )
  ].

generic_response(Body0, Request) ->
  Headers = [{"Access-Control-Allow-Origin", "*"}, {"Content-Type", "application/json"}],
  Body = jsx:encode(Body0),
  {200, Headers, Body, Request}.

async_message() ->
  [{ok, <<"Start signal sent, this is an async call, to follow up the sync status, please use 'status' endpoint">>}].

-endif.