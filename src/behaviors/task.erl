%%% @doc Task behavior
%%%
%%% Generic tasks must implement this behavior
%%% or its defined functions
%%% @author elpaisa
%%% @copyright (C) 2017, John L. Diaz
%%% Created : 16. Mar 2017 11:37 AM
%%% @end
-module(task).
-author("elpaisa").

%% API
-export([behaviour_info/1]).

behaviour_info(callbacks) -> [{init, 2}, {stop, 0}, {documents, 5}];
behaviour_info(_) -> undefined.