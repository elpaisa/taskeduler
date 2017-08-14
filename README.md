[Build Status / link to build job](#)

# taskeduler

Highly Distributed Application for executing tasks in a concurrent and parallel manner

## Overview

This distributed service allows to execute scheduled tasks using a task controller list, provided in the config.
Using this module as a dependency of any project enables the main application to define workers and do 
whatever it needs to accomplish a set of tasks, this is suitable for services that need to sync or process periodically
any amount of data, the best example would be obtaining a list of customers and process them using an interval of time.
All modules for tasks must implement ´-behavior(task).´, the controller module is used to obtain the list of tasks to 
execute. If used as a main application, see example functions test_controller.erl for
testing, these are the mandatory implementations by the consumer application.

If your main application requires additional endpoints, there is no need to define a new service, all you have
to do is to specify the module that will contain the functions exposed as endpoints in the config as `{rest_handler, your_module}`, 
all functions exposed with arity of 2 will be public and searchable by the service in that module, so function_name(UrlParam1, Body), 
will be used if it is requested, if no request Body is received (usually `GET`), in the request and no url param, these will come as 
`undefined` atoms, the endpoint in this case will be `your_api/v1/function_name/param1` or `your_api/v1/function_name`, 
if the function needs to be async can be called as `your_api/v1/async/function_name/param1` or `your_api/v1/async/function_name`.

Please see project definition [documentation][api-documentation]

## Ownership

taskeduler is owned by the [elpaisa][email]. Feel free to [email me][email]."

## Dependencies

This service depends on Cowboy for defining the http API


## How to consume taskeduler

Endpoint | Parameters | Description
----- | ----------- | --------
start |  | Starts all workers
start/1 | "worker-name", {test_daily, test_regular}  | Starts a specific worker
stop | | Stops all workers
stop/1 | "worker-name", {test_daily, test_regular} | Stops a specific worker
status | | Responds the status of all workers
status/1 | "worker-name", {test_daily, test_regular} | Responds status for a specific worker
re-sync | | Starts all workers and runs an loop for the given interval of days defined in sys.config
re-sync/1 | "worker-name", {test_daily, test_regular} | Runs re-sync for a specific worker


## How to contribute

Always submit issues for discussion before creating any pull requests.

## How to report defects

Open github issues

## Running locally

For running locally please use.

```sh
git clone git@github.com:elpaisa/taskeduler.git.git
cd taskeduler
make shell
```

taskeduler requires configuration parameters. Copy the 
`sys.config.tmpl` as `config/sys.config` and edit it accordingly:

```sh
cp sys.config.tmpl config/sys.config
vim sys.config
```

```erlang
%%-*- mode: erlang -*-
[
  {taskeduler, [
    {max_workers, 12},
    {max_retries, 12},
    {controller_module, test_controller},
    {rest_handler, test_controller},
    {service_name, "/taskeduler/v1"},
    {nodes, ['nonode@nohost']},
    {workers, [
        {test,
            [ {re_sync_days, 7}, {max_fetch, 2000}],
            [ {test_regular, 60, minutes}, {test_daily, 1, days} ] %% Worker definitions
        }
    ]}
  ]},

  {sasl, [
    {sasl_error_logger, false}
  ]}
].
% vim:ft=erlang

```

Once you have filled out the above changes to the `sys.config`, you can start
taskeduler:

```sh
make shell
```

Or

```
./rebar3 shell
```

### Testing

To run the tests, execute:

```sh
make test
```

For unit tests and for common (integration) tests, if they are different. Note that the `make test` target should generally execute whatever
testing can be run by continuous integration: thus, if the common tests require some specialized
setup/environment that CI is not configured for, this target should not include `ct`.

#### Unit Tests

To run the unit tests alone, execute:

```sh
make eunit
```

OR 

```
./rebar3 eunit
```


If there is something unique about the eunit configuration, or the output of the tests or code
coverage are sent somewhere different than conventional, describe here how to view those reports.

#### Common tests

To run the common tests alone, execute:

```sh
make ct
```

The common tests for taskeduler are integration tests that require all dependencies above to be
available. The node started for the common test uses the erl.config file in the project's root
directory.


### HTTP API documentation

In addition to viewing the [API documentation][api-documentation], you can also build it locally
for testing updates to documentation prior to deploying it. To build documentation locally, you
must install [apidoc][apidoc] (see instructions [here][install-apidoc]). Once you have it
installed, you can build the documentation:

```sh
make doc
```

To view the documentation after it is built, open the file `doc/api/index.html`:

```sh
% Open in Mac OS X with default browser
open docs/index.html
```

### Doing a release

This command creates a tarball in `_build/default/rel/taskeduler/`, the full application
is self contained in there.

```sh
make release
```


### From Jenkins

To create an rpm for installation, execute the below command, that will do test, create a self
contained release and build an rpm ready for deployment, later on 
`./_build/default/rel/taskeduler/bin/taskeduler start` will create a service, add
this to chkconfig in the server in order to do it a real centos service.

```sh
make rpm
```

[design-doc]: #
[email]: mailto:clientes@desarrollowebmedellin.com
[api-documentation]: https://elpaisa.github.io/taskeduler/
[apidoc]: http://apidocjs.com

<!--- vim: sw=4 et ts=4 -->
