%%% @doc Controller Behavior
%%%
%%% All applications including this module as
%%% a dependency, must have a module that implements
%%% this behavior or its functions with the specified arity
%%% This implementor module must be added to taskeduler config
%%% in the application config file as {controller_module, module_name}
%%%
%%% @author elpaisa
%%% @copyright (C) 2017, John L. Diaz
%%% Created : 16. Mar 2017 11:37 AM
%%%
%%% @end
%%%
-module(controller).
-author("elpaisa").

%% API
-export([behaviour_info/1]).

behaviour_info(callbacks) -> [{start,1}, {stop,0}, {task_list, 0}, {prepare, 5}, {process_done, 1}, {task_end, 3}];
behaviour_info(_) -> undefined.