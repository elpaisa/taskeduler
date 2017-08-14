-ifndef(taskeduler_hrl).
-define(taskeduler_hrl, 1).

-define(TIME_ZONE, taskeduler:get_env(time_zone, <<"America/Chicago">>)).
-define(TASKS_SCHEDULER, sync_scheduler).
-define(TASK_CONTROLLER, taskeduler:get_env(controller_module)).
-define(STATUS_TABLE, status).
-define(WORKERS_TABLE, workers).
-define(PERFORMANCE, performance).
-define(SERVICE_CONTEXT, []).
-define(LISTENER, listeners_table).
-define(SERVICE_PREFIX, "/taskeduler/v1").

-record(service_request, {http_request::term()}).

-endif.