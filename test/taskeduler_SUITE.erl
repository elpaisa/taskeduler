-module(taskeduler_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile([export_all]).

all() -> [].

init_per_suite(Config) ->
    taskeduler:start(),
    Config.

end_per_suite(_Config) ->
    ok.
