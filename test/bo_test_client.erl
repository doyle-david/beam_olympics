-module(bo_test_client).

-export([start/1, stop/1]).
-export([signup/2, task/2, submit/3, skip/2, score/2, stats/1]).
-export([gen_call/2]).

-type task() :: bo_task:task().
-type player_name() :: term().

-spec start(atom()) -> {ok, node()}.
start(NodeName) ->
  {ok, Node} = slave:start("127.0.0.1", NodeName),
  {ok, Cwd} = file:get_cwd(),
  TestEbin = filename:join(Cwd, "../../lib/beam_olympics/test"),
  proc_lib:spawn(Node, code, add_paths, [[TestEbin]]),
  ct:log("Nodes after starting ~p: ~p", [NodeName, nodes(connected)]),
  {ok, Node}.

-spec stop(node()) -> ok.
stop(Node) ->
  ok = slave:stop(Node),
  ct:log("Nodes after stopping ~p: ~p", [Node, nodes(connected)]),
  ok.

-spec signup(node(), player_name()) -> {ok, task()} | {error, term()}.
signup(Node, Player) -> call(Node, {signup, Player}).

-spec task(node(), player_name()) -> {ok, task()} | {error, term()}.
task(Node, Player) -> call(Node, {task, Player}).

-spec submit(node(), player_name(), term()) ->
    {ok, bo_task:task()} | the_end | {error, term()} | {failures, [term()]}.
submit(Node, Player, Solution) -> call(Node, {submit, Player, Solution}).

-spec skip(node(), player_name()) ->
    {ok, bo_task:task()} | the_end | {error, term()}.
skip(Node, Player) -> call(Node, {skip, Player}).

-spec score(node(), player_name()) -> {ok, integer()} | {error, term()}.
score(Node, Player) -> call(Node, {score, Player}).

-spec stats(node()) -> bo_players_repo:stats().
stats(Node) -> call(Node, stats).

call(Node, Msg) ->
  Caller = self(),
  Pid = proc_lib:spawn(Node, ?MODULE, gen_call, [Caller, Msg]),
  receive
    {Pid, Response} -> Response
  after 5000 ->
    throw({timeout, Node, Msg})
  end.

-spec gen_call(pid(), term()) -> {pid(), term()}.
gen_call(Caller, Msg) ->
  try gen_server:call({bo_server, 'bo_test@127.0.0.1'}, Msg, 60000) of
    Something ->
      Caller ! {self(), Something}
  catch
    _:Error ->
      Caller ! {self(), {error, {Error, erlang:get_stacktrace()}}}
  end.
