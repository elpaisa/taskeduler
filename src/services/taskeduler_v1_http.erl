%%% @doc Rest API HTTP helper
%%%
%%% This module has the predefined endpoints
%%% Exposed to start, stop, get the status of a worker
%%%
%%% @author elpaisa
%%% @copyright (C) 2017, John L. Diaz
%%%
%%% Created : 09. Mar 2017 10:21 AM
%%%
%%% @end
-module(taskeduler_v1_http).

-include("taskeduler.hrl").
%% HTTP Resource functions
-export([get/2, post/2, put/2, delete/2, head/2]).

-export([make_response/2, generic_call/2, require_json_body/1]).

%%
%% @doc Endpoint to get the current status of the sync processes
%%
-spec get(list(), Req :: term()) ->
  {integer(), Headers :: list(), Body :: binary(), Request :: term()}.
get([<<"status">>], Req) ->
  generic_call(Req, {taskeduler_api, status, []});

%%
%% @doc Endpoint to get the current status of a specific worker
%%
get([<<"status">>, WorkerName], Req) ->
  generic_call(Req, {taskeduler_api, status, [utils:need_atom(WorkerName)]});

%%
%% @doc Endpoint to start all sync processes, this gives an async response
%%
get([<<"start">>], Req) ->
  generic_call(Req, {taskeduler_srv, start, []});
%%
%% @doc get/2
%%
%% Endpoint to stop all sync processes
%%
get([<<"stop">>], Req) ->
  generic_call(Req, {taskeduler_api, stop, []});

%%
%% @doc Endpoint to start a sync process, it is an async call, otherwise can take long time to respond
%%
get([<<"start">>, WorkerName], Req) ->
  generic_call(Req, {taskeduler_srv, start, [utils:need_atom(WorkerName)]});

%%
%% @doc Endpoint to start a sync process, it is an async call, otherwise can take long time to respond
%%
get([<<"resume">>, WorkerName], Req) ->
  generic_call(Req, {taskeduler_srv, resume, [utils:need_atom(WorkerName)]});
%%
%% @doc Determines if a worker last run time is older than the interval
%% specified in its config
%%
get([<<"on-time">>, WorkerName], Req) ->
  generic_call(Req, {taskeduler_api, on_time, [utils:need_atom(WorkerName)]});

%%
%% @doc Endpoint to start a sync process, it is an async call, otherwise can take long time to respond
%%
get([<<"by-date">>, ModuleName, Date], Req) ->
  ParsedDate = ec_date:parse(binary_to_list(Date)),
  {{Year, Month, Day}, _} = ParsedDate,
  case calendar:valid_date(Year, Month, Day) of
    true
      when Year >= 2009 ->
      io:format("Valid date received ~p~n", [[Year, Month, Day]]),
      generic_call(Req, {taskeduler_srv, by_date, [utils:need_atom(ModuleName), Date]});
    _ ->
      make_response({error, invalid_date}, Req)
  end;

%%
%% @doc Endpoint to stop a single sync process
%%
get([<<"stop">>, WorkerName], Req) ->
  generic_call(Req, {taskeduler_api, stop, [utils:need_atom(WorkerName)]});

%%
%% @doc Endpoint to re index all processes
%%
get([<<"re-sync">>], Req) ->
  generic_call(Req, {taskeduler_srv, re_sync, []});

%%
%% @doc Endpoint to re index an specific module for a date
%%
get([<<"re-sync">>, ModuleName], Req) ->
  generic_call(Req, {taskeduler_srv, re_sync, [utils:need_atom(ModuleName)]});

%%
%% @doc Endpoint catch additional endpoints defined in config
%%
get([Endpoint], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, undefined, undefined]});
get([Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, Param, undefined]});
get([<<"async">>, Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [<<"async">>, Endpoint, Param, undefined]});
get(_Path, _Req) ->
  {error, not_found}.


%%
%% @doc Endpoint catch additional endpoints defined in config
%%
post([Endpoint], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, undefined, require_json_body(Req)]});
post([Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, Param, require_json_body(Req)]});
post([<<"async">>, Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [<<"async">>, Endpoint, Param, require_json_body(Req)]}).

%%
%% @doc Endpoint catch additional endpoints defined in config
%%
put([Endpoint], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, undefined, require_json_body(Req)]});
put([Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, Param, require_json_body(Req)]});
put([<<"async">>, Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [<<"async">>, Endpoint, Param, require_json_body(Req)]}).

%%
%% @doc Endpoint catch additional endpoints defined in config
%%
delete([Endpoint], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, undefined, undefined]});
delete([Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [Endpoint, Param, undefined]});
delete([<<"async">>, Endpoint, Param], Req) ->
  generic_call(Req, {taskeduler_srv, rest_call, [<<"async">>, Endpoint, Param, undefined]}).



-spec head(_Path :: term(), _Req :: term()) -> {error, not_implemented}.
%%
%% @private head request
%%
head(_Path, _Req) ->
  {error, not_implemented}.

%%
%% @private get an standard response
%%
-spec generic_call(
    Req :: term(), tuple()
) -> {200, list(), binary(), term()}.
generic_call(Req, {_, _, [_, _, invalid_body]})->
  {400, Req};
generic_call(Req, {M, F, _Args})->
  generic_call(Req, apply(M, F, _Args));
generic_call(Req, _Data) ->
  try
    make_response(_Data, Req)
  catch
    {error, Reason} ->
      utils:err("Reason: ~p", [Reason]),
      {400, <<"Invalid Input">>};
    {bad_request, Reason} ->
      utils:err("Reason: ~p", [Reason]),
      {400, <<"Invalid input">>};
    {server_error, Reason} ->
      utils:err("Reason: ~p", [Reason]),
      {500, <<"Internal Server Error">>};
    {not_found, Reason} ->
      utils:err("Reason: ~p", [Reason]),
      {404, <<"Resource not found">>}
  end.

%%
%% @private get an standard response
%%
-spec make_response(Body :: binary(), Request :: term()) ->
  {integer(), Headers :: list(), Body :: binary(), Request :: term()}.
make_response(service_unavailable, Request)->
  do_respond(503, <<"Service is unavailable">>, Request);
make_response(not_found, Request)->
  do_respond(404, <<"Not found">>, Request);
make_response(bad_request, Request)->
  do_respond(400, <<"Bad request">>, Request);
make_response(unauthorized, Request)->
  do_respond(401, <<"Unauthorized">>, Request);
make_response(forbidden, Request)->
  do_respond(403, <<"Forbidden">>, Request);
make_response(Body, Request) ->
  do_respond(200, Body, Request).

do_respond(Code, Body, Request) when is_tuple(Body)->
  do_respond(Code, [Body], Request);
do_respond(Code, Body, Request) when is_atom(Body)->
  do_respond(Code, [{ok, Body}], Request);
do_respond(Code, Body, Request)->
  Headers = [{"Access-Control-Allow-Origin", "*"}, {"Content-Type", "application/json"}],
  {Code, Headers, jsx:encode(Body), Request}.

require_json_body(Req) ->
  {_Size, Json} = taskeduler_service:require_body(Req),
  try jsx:decode(Json) of
    {error, _, _} ->
      throw(bad_request);
    {error, _} ->
      throw(bad_request);
    [] ->
      throw(bad_request);
    Data ->
      Data
  catch
    _:_ ->
      throw(bad_request)
  end.
