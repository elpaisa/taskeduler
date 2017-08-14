%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%% @doc
%%% Handles HTTP service with cowboy module, puts an abstraction
%%% layer on top of the request calls
%%% @end
%%% Created : 14. Jul 2017 11:41 AM
-module(taskeduler_service).
-author("johnleytondiaz").
-behavior(cowboy_handler).

-include("taskeduler.hrl").

-define(PATHS, "/:a/[:b]/[:c]/[:d]").

-export([init/2]).
%% API
-export([add_service/1, remove_service/1, require_body/1]).

%%
%% @doc Catches all the http routes of the service
%%
-spec init(term(), term()) -> term().
init(Req0, State) ->
  Ref = maps:get(ref, Req0),
  Path = get_path(Ref, cowboy_req:path(Req0)),
  request(
    {cowboy_req:method(Req0), Path, cowboy_req:headers(Req0)},
    Ref, Req0, State
  ).

%%
%% @doc Checks if a listener is already loaded in cowboy, otherwise loads it,
%% if no modules have been loaded starts the http service
%%
-spec add_service({ServiceName :: string(), ModuleName :: atom(), Options :: list()}) -> ok.
add_service({ServiceName, ModuleName, _}) ->
  Port = taskeduler:get_env(port, 8081),
  load(loaded(), ServiceName, ModuleName, Port).

%%
%% @private Starts an http listener using cowboy
%%
-spec start_server(ServiceName :: string(), ModuleName :: atom(), Port :: integer()) -> ok.
start_server(ServiceName, ModuleName, Port) ->
  Dispatch = cowboy_router:compile([
    {'_', [{ServiceName ++ ?PATHS, ?MODULE, []}]}
  ]),
  {ok, _} = cowboy:start_clear(
    ModuleName, [{port, Port}], #{env => #{dispatch => Dispatch}}
  ),
  cache({ServiceName, ModuleName}),
  ok.

%%
%% @private Adds a listener to the started cowboy server
%%
-spec add_listener(ServiceName :: string(), ModuleName :: atom()) -> ok.
add_listener(ServiceName, ModuleName) ->
  Dispatch = cowboy_router:compile([
    {'_', [{ServiceName, ?MODULE, []}]}
  ]),
  cowboy:set_env(
    ModuleName, dispatch,
    cowboy_router:compile(Dispatch)
  ),
  cache({ServiceName, ModuleName}),
  ok.

%%
%% @private Checks if a listener is already loaded in cowboy, otherwise loads it,
%% if no modules have been loaded starts the http service
%%
-spec load(Loaded :: list(), ServiceName :: string(), ModuleName :: atom(), Port :: integer()) -> ok.
load([], ServiceName, ModuleName, Port) ->
  start_server(ServiceName, ModuleName, Port);
load(_Loaded, ServiceName, ModuleName, _) ->
  add_listener(ServiceName, ModuleName).

%%
%% @private Inserts a listener name into the ETS for cache, this
%% function is invoked from the service listener loader functions
%%
-spec cache({ServiceName :: string(), ModuleName :: atom()}) -> term().
cache({ServiceName, ModuleName}) ->
  Unique = [{S, M} || {S, M} <- loaded(), M =/= ModuleName],
  Loaded = lists:append(Unique, [{ModuleName, ServiceName}]),
  taskeduler_cache:insert(?LISTENER, {loaded, Loaded}).

%%
%% @private Gets cached listeners that have been loaded into cowboy
%%
-spec loaded() -> list().
loaded() ->
  taskeduler_cache:get(?LISTENER, loaded).

%%
%% @private Gets the prefix of the service url, usually the ServiceName param
%% that is stored in the ETS cache
%%
-spec prefix(ModuleName :: atom()) -> string().
prefix(ModuleName) ->
  proplists:get_value(ModuleName, loaded(), ?SERVICE_PREFIX).

remove_service({_ServiceName, _ModuleName, []}) ->
  ok.

%%
%% @private Parses the path as a list and removes the prefix
%% usually the service name.
%%
-spec get_path(ModuleName :: atom(), Path :: binary()) -> list().
get_path(ModuleName0, Path0) ->
  Ref = utils:need_binary(prefix(ModuleName0)),
  Path = re:replace(Path0, Ref, "", [global, {return, list}]),
  [utils:need_binary(S) || S <- string:tokens(Path, "/")].

%%
%% @private Calls the module function according to the Method given
%% For now it only supports: [GET, POST, PUT, DELETE]
%%
-spec request(
    {Method :: binary(), Path :: list(), Headers :: list()},
    ModuleName :: atom(), Req0 :: term(), State :: term()
) -> term().
request({<<"GET">>, Path, _}, ModuleName, Req0, State) ->
  Response = erlang:apply(ModuleName, get, [Path, Req0]),
  response(Response, Req0, State);
request({<<"POST">>, Path, _}, ModuleName, Req0, State) ->
  Response = erlang:apply(ModuleName, post, [Path, Req0]),
  response(Response, Req0, State);
request({<<"PUT">>, Path, _}, ModuleName, Req0, State) ->
  Response = erlang:apply(ModuleName, put, [Path, Req0]),
  response(Response, Req0, State);
request({<<"DELETE">>, Path, _}, ModuleName, Req0, State) ->
  Response = erlang:apply(ModuleName, delete, [Path, Req0]),
  response(Response, Req0, State).

%%
%% @private Parses the path as a list and removes the prefix
%% usually the service name.
%%
-spec response(
    {Code :: integer(), Headers :: list(), Response :: binary(), Req :: term()},
    Req0 :: term(), State :: term()
) -> {ok, Req :: term(), State :: term()}.
response({Code, _Headers, Response, _}, Req0, State) ->
  Req = cowboy_req:reply(Code, #{<<"content-type">> => <<"application/json">>},
    Response,
    Req0),
  {ok, Req, State}.


require_body(Req) ->
  cowboy:body(Req).