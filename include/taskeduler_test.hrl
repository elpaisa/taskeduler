-ifndef(taskeduler_test_hrl).
-define(taskeduler_test_hrl, 1).

-include("taskeduler.hrl").
-define(TEST_NOW, 1434234486).
-define(TEST_AFTER, 1434234500).
-define(TEST_TIMEOUT, 50).
-define(TEST_TIMESTAMP, 0).

-define(TEST_OPTS,
  [{requires_mapping, true}, {re_sync_days, 7}, {max_test_fetch, 2000}]
).

-define(TEST_WORKERS,
  [
    {test_controller,
      [ {requires_mapping, true}, {re_sync_days, 7}, {max_test_fetch, 2000}],
      [ {test_regular, 60, minutes}, {test_daily, 1, days} ] %% Worker definitions
    }
  ]
).


-endif.