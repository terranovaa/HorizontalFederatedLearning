%%%-------------------------------------------------------------------
%%% @author BPT
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%     This module contains the code needed for the server node
%%%     of a federated learning distributed algorithm.
%%%     The server node spawns different clients and monitor them.
%%%     After that, the server ask for the execution of rounds and propagate this information to the Supervisor.
%%%     The server node is also in charge of re-spawning the clients if we still have
%%%     attempts to use.
%%% @end
%%% Created : 27. nov 2021 10:57
%%%-------------------------------------------------------------------
-module(server).
-author("BPT").

%% API
-import('rpc', [call/3, call/4]).
-import('cMeansServer', [getResults/6, getFinishedReason/0, getOutputIterationResults/1, getRoundParameters/1, startAlgorithm/2]).

-export([start/3]).

start({NClients,NMinClients, Dataset, NumFeatures, ClientsHostnames, RandomClients, RandomClientsSeed, MaxNumberRounds, RandomClientsSeed, RandomClients, Timeout, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, Mode}, AlgParams, Supervisor) ->
  io:format("Server - Launching python server...~n"),
  createPythonServer(),
  io:format("Server - Generating chunks...~n"),
  DatasetChunks = generateChunks(NClients, Dataset, Mode, NumFeatures),
  io:format("Server - Starting the algorithm...~n"),
  FirstIterationParameters = startAlgorithm(AlgParams, NumFeatures),
  CompleteListClients = spawnClients(NClients, DatasetChunks, ClientsHostnames, [], Timeout),
  loop(NClients, NMinClients, CompleteListClients, DatasetChunks, NumFeatures, RandomClientsSeed, RandomClients,
    ClientsHostnames, MaxNumberRounds, RandomClientsSeed, Timeout, MaxAttemptsClientCrash, MaxAttemptsOverallCrash,
     0, FirstIterationParameters, 0, AlgParams, Supervisor).

spawnClients(0, _, _, ListClients, _) -> ListClients;
spawnClients(_, [], _, ListClients, _) -> ListClients;
spawnClients(_, _, [], ListClients, _) -> ListClients;
spawnClients(NClients, [ChunkHead | ChunkTail], [HostnameHead | HostnameTail], ListClients, Timeout) ->
  ServerPID = self(),
  {Client, _} = spawn_monitor(list_to_atom(HostnameHead), 'client', start, [ChunkHead, ServerPID, Timeout]),
  io:format("Server - Spawned ~p~n", [Client]),
  ClientInfo = {HostnameHead, Client, ChunkHead, 0},
  List = ListClients ++ [ClientInfo],
  spawnClients(NClients - 1, ChunkTail, HostnameTail, List, Timeout).

loop(NClients, NMinClients, ListClients, DatasetChunks, NumFeatures, RandomClientsSeed, RandomClients,
    ClientsHostnames, MaxNumberRounds, RandomClientsSeed, Timeout, MaxAttemptsClientCrash, MaxAttemptsOverallCrash,
    NumCrashes, IterationElements, ExecutedRounds, AlgParams, Supervisor) ->
  case ExecutedRounds >= MaxNumberRounds of
    true -> % maximum number of rounds reached
      Supervisor ! {self(), reached_max_rounds},
      io:format("Server - Max number rounds reached~n"),
      io:format("Server - Shutting down all nodes~n"),
      shutdownClients(ListClients);
    false -> % new iteration
      io:format("Server - Getting into the ~p-th iteration of the loop~n", [ExecutedRounds + 1]),
      InvolvedClients = getInvolvedClients(NClients, NMinClients, ListClients, RandomClientsSeed, RandomClients),
      RoundParameters = performRound(IterationElements, InvolvedClients),
      {Client_responses, UpdatedClients, AvailableHostnames, NewNumCrashes} = waitResponses(Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NumCrashes, ClientsHostnames, ListClients, InvolvedClients, []),
      io:format("Server - Received all results, joining them...~n"),
      {NewIterationElements, Finished} = getResults(AlgParams, MaxNumberRounds, NumFeatures, Client_responses, ExecutedRounds, IterationElements),
      sendResults(Supervisor, NewIterationElements, NewNumCrashes, InvolvedClients, UpdatedClients, ExecutedRounds),
      case Finished == 0 of % reason of termination of the specific algorithm reached
        true ->
          Supervisor ! {self(), completed, getFinishedReason()},
          io:format("Server - Shutting down all nodes~n"),
          shutdownClients(UpdatedClients);
        false ->
          loop(NClients, NMinClients, UpdatedClients, DatasetChunks, NumFeatures, RandomClientsSeed, RandomClients,
            AvailableHostnames, MaxNumberRounds, RandomClientsSeed, Timeout, MaxAttemptsClientCrash,
            MaxAttemptsOverallCrash, NewNumCrashes, NewIterationElements, ExecutedRounds + 1, AlgParams, Supervisor)
      end
  end.

performRound(IterationElements, InvolvedClients) ->
  RoundParameters = getRoundParameters(IterationElements),
  io:format("Server - Sending request of execution to the nodes..~n"),
  askForRound(InvolvedClients, RoundParameters),
  RoundParameters.

getInvolvedClients(NClients, NMinClients, ListClients, RandomClientSeed, RandomClients) ->
  io:format("Server - Selecting nodes to be involved..~n"),
  [_|[IPList]] = string:split(atom_to_list(node()),"@"),
  Node = list_to_atom("py@" ++ IPList),
  InvolvedClients = case NClients == NMinClients of
    false when RandomClients == true -> % extract some clients for this iteration
      InvolvedClientsIndexes = rpc:call(Node, 'server', 'erlang_request_get_involved_clients', [{NClients, NMinClients, RandomClientSeed}]),
      selectClients(ListClients, InvolvedClientsIndexes);
    false when RandomClients == false -> % extract a fixed list of clients
      lists:sublist(ListClients, NMinClients);
    true -> % use all clients if requested, RandomClients is meaningless
      ListClients
  end,
  io:format("Server - Selected nodes:~n"),
  printList(InvolvedClients),
  InvolvedClients.

selectClients(_, []) -> [];
selectClients(ListClients, [FirstClientIndex | OtherClientIndexes]) ->
  [lists:nth(FirstClientIndex + 1, ListClients) | selectClients(ListClients, OtherClientIndexes)].

shutdownClients([]) -> ok;
shutdownClients([H | T]) ->
  {_, Pid, _, _} = H,
  Pid ! {self(), shutdown},
  shutdownClients(T).

askForRound([], _) -> ok;
askForRound([H | T], RoundParameters) ->
  {_, Pid, _, _} = H,
  Pid ! {self(), compute_round, RoundParameters},
  askForRound(T, RoundParameters).

waitResponses(_, _, _, _, NumCrashes, ClientsHostnames, UpdatedClients, [], ResultsList) ->
  {ResultsList, UpdatedClients, ClientsHostnames, NumCrashes};
waitResponses(Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NumCrashes, ClientsHostnames, ListClients, PidList, ResultsList) ->
  receive
    {From, results, Results} -> % client provided results
      case lists:keymember(From, 2, PidList) of
        true ->
          NewPidList = lists:keydelete(From, 2, PidList),
          NewResultsList = lists:append([Results], ResultsList),
          waitResponses(Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NumCrashes, ClientsHostnames, ListClients, NewPidList, NewResultsList);
        false ->
          waitResponses(Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NumCrashes, ClientsHostnames, ListClients, PidList, ResultsList)
      end;
    {'DOWN', _, _, Pid, Reason} -> % client crashed
      io:format("Server - Client ~w has crashed for reason: ~w ~n", [Pid, Reason]),
      {NewNumCrashes, UpdatedListClients, UpdatedPidList} = handleClientFault(Pid, Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NumCrashes, ClientsHostnames, ListClients, PidList),
      waitResponses(Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NewNumCrashes, ClientsHostnames, UpdatedListClients, UpdatedPidList, ResultsList);
    _othermsg ->
      waitResponses(Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NumCrashes, ClientsHostnames, ListClients, PidList, ResultsList)
  end.

handleClientFault(Pid, Timeout, RoundParameters, MaxAttemptsClientCrash, MaxAttemptsOverallCrash, NumCrashes, ClientsHostnames, ListClients, PidList) ->
  NewNumCrashes = checkOverallCrashes(NumCrashes, MaxAttemptsOverallCrash),
  {Hostname, Pid, Chunk, Attempts} = lists:keyfind(Pid, 2, ListClients),
  NewPidList = lists:keydelete(Pid, 2, PidList), % delete member from list of pids that have to answer this round
  UpdatedClients = lists:keydelete(Pid, 2, ListClients), % delete member from list of all pids
  case Attempts >= MaxAttemptsClientCrash of
     true -> % reached max attempts
       io:format("Server - Reached max attempts for node ~w at location ~p ~n", [Pid, Hostname]),
       AvailableHostnames = lists:delete(Hostname, ClientsHostnames),
       NextHostname = selectNextLocation(ListClients, AvailableHostnames), % select another location
       ClientInfo = spawnClientAtHostname(NextHostname, Chunk, Timeout, 0, RoundParameters),
       UpdatedPidList = NewPidList ++ [ClientInfo],
       UpdatedListClients = UpdatedClients ++ [ClientInfo],
       {NewNumCrashes,UpdatedListClients, UpdatedPidList};
     false ->
       timer:sleep(10000),
       ClientInfo = spawnClientAtHostname(Hostname, Chunk, Timeout, Attempts, RoundParameters),
       UpdatedPidList = NewPidList ++ [ClientInfo],
       UpdatedListClients = UpdatedClients ++ [ClientInfo],
       {NewNumCrashes,UpdatedListClients, UpdatedPidList}
  end.

checkOverallCrashes(NumCrashes, MaxAttemptsOverallCrash) ->
  NewNumCrashes = NumCrashes + 1,
  case NewNumCrashes > MaxAttemptsOverallCrash of
    true ->
      exit(failed_MAX_CRASHES_REACHED);
    false ->
      io:format("Server - Number of crashes: ~w ~n", [NewNumCrashes]),
      NewNumCrashes
  end.

% restarts the pyrlang node if dead
createPythonServer() ->
    [_|[IPList]] = string:split(atom_to_list(node()),"@"),
    NodeString = "py@" ++ IPList,
    Node = list_to_atom(NodeString),
    try throw(rpc:call(Node, 'server', 'is_alive', []))
    catch
        {badrpc,nodedown} ->
            io:format("Server - Pyrlang node dead, re-starting the pyrlang node...~n"),
            spawn(fun() -> os:cmd("python3 \"erlangFiles/server.py\" " ++ NodeString) end),
            timer:sleep(6000),
            createPythonServer();
         _ -> io:format("Server - Pyrlang node up...~n")
    end.

generateChunks(NClients, Dataset, Mode, NumFeatures) ->
    [_|[IPList]] = string:split(atom_to_list(node()),"@"),
    Node = list_to_atom("py@" ++ IPList),
    rpc:call(Node, 'server', 'generate_chunks', [NClients, Dataset, Mode, NumFeatures]).

sendResults(Supervisor, NewIterationElements, NewNumCrashes, InvolvedClients, UpdatedClients, ExecutedRounds) ->
    Supervisor ! {self(), round, {getOutputIterationResults(NewIterationElements), NewNumCrashes, InvolvedClients, UpdatedClients, ExecutedRounds + 1}}.

printList([]) -> ok;
printList([H | T]) ->
  {_, Pid, _, _} = H,
  io:format("Server - Element: ~p~n", [Pid]),
  printList(T).

spawnClientAtHostname(Hostname, Chunk, Timeout, Attempts, RoundParameters) ->
  {Client, _} = spawn_monitor(list_to_atom(Hostname), 'client', start, [Chunk, self(), Timeout]),
  io:format("Server - Spawned ~p at location ~p. Attempt ~p ~n", [Client, Hostname, Attempts]),
  Client ! {self(), compute_round, RoundParameters},
  {Hostname, Client, Chunk, Attempts + 1}.

selectNextLocation(_, []) -> exit(failed_NO_LOC_AVAILABLE);
selectNextLocation(ListClients, [HostnamesHead | HostnamesTail]) ->
  case lists:keymember(HostnamesHead, 1, ListClients) of
    true ->
      selectNextLocation(ListClients, HostnamesTail);
    false ->
      HostnamesHead
  end.
