%%%----------------------------------------------------------------------
%%%
%%% @copyright 2010 mgee (Ming Game Engine Erlang)
%%%
%%% @author odinxu, 2010-01-11
%%% @doc the mgee ctl module
%%% @end
%%%
%%%----------------------------------------------------------------------
-module(mgeeweb_ctl).

-export([start/0,
	 init/0,
	 process/1
	 ]).

-include("mgeeweb_ctl.hrl").

-spec start() -> no_return(). 
start() ->
    case init:get_plain_arguments() of
	[SNode | Args]->
	    SNode1 = case string:tokens(SNode, "@") of
		[_Node, _Server] ->
		    SNode;
		_ ->
		    case net_kernel:longnames() of
			 true ->
			     SNode ++ "@" ++ inet_db:gethostname() ++
				      "." ++ inet_db:res_option(domain);
			 false ->
			     SNode ++ "@" ++ inet_db:gethostname();
			 _ ->
			     SNode
		     end
	    end,
	    Node = list_to_atom(SNode1),
	    Status = case rpc:call(Node, ?MODULE, process, [Args]) of
			 {badrpc, Reason} ->
			     ?PRINT("RPC failed on the node ~w: ~w~n",
				       [Node, Reason]),
			     ?STATUS_BADRPC;
			 S ->
			     S
		     end,
	    halt(Status);
	_ ->
	    print_usage(),
	    halt(?STATUS_USAGE)
    end.

-spec init() -> 'ok'.
init() ->
    ets:new(mgeeweb_ctl_cmds, [named_table, set, public]),
    ets:new(mgeeweb_ctl_host_cmds, [named_table, set, public]),
    ok.


-spec process([string()]) -> integer().
process(["status"]) ->
    {InternalStatus, ProvidedStatus} = init:get_status(),
    ?PRINT("Node ~w is ~w. Status: ~w~n",
              [node(), InternalStatus, ProvidedStatus]),
    case lists:keysearch(mgeeweb, 1, application:which_applications()) of
        false ->
            ?PRINT("node is not running~n", []),
            ?STATUS_ERROR;
        {value,_Version} ->
            ?PRINT("node is running~n", []),
            ?STATUS_SUCCESS
    end;

process(["stop"]) ->
    init:stop(),
    ?STATUS_SUCCESS;

process(["restart"]) ->
    init:restart(),
    ?STATUS_SUCCESS.


print_usage() ->
    CmdDescs =
	[{"status", "get node status"},
	 {"stop", "stop node"},
	 {"restart", "restart node"}
	 ] ++
	ets:tab2list(mgeeweb_ctl_cmds),
    MaxCmdLen =
	lists:max(lists:map(
		    fun({Cmd, _Desc}) ->
			    length(Cmd)
		    end, CmdDescs)),
    NewLine = io_lib:format("~n", []),
    FmtCmdDescs =
	lists:map(
	  fun({Cmd, Desc}) ->
		  ["  ", Cmd, string:chars($\s, MaxCmdLen - length(Cmd) + 2),
		   Desc, NewLine]
	  end, CmdDescs),
    ?PRINT(
      "Usage: mgeewebctl [--node nodename] command [options]~n"
      "~n"
      "Available commands in this node node:~n"
      ++ FmtCmdDescs ++
      "~n"
      "Examples:~n"
      "  mgeewebctl restart~n"
      "  mgeewebctl --node node@host restart~n"
      "  mgeewebctl vhost www.example.org ...~n",
     []).
