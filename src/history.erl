-module(history).
-behaviour(gen_server).


-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
    terminate/2, code_change/3]).

-export([start_link/0, log/2, last/2, dump/1]).


-record(order, {
        id,
        user_name,
        item_name, 
        price,
        quantity,
        timestamp
    }).


-spec log(string(), #order{}) -> ok | {error, term()}.
-spec last(string(), integer()) -> {ok, list()} | {error, term()}.
-spec dump(string()) -> {ok, list()} | {error, term()}.




start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


init([]) ->
    mnesia:create_schema([node()]),
    mnesia:start(),
    case mnesia:create_table(history, [
        {attributes, [user_id, record]},
        {disc_copies, [node()]}    
    ]) of 
        {atomic, ok} -> ok;
        {aborted, {already_exists, history}} -> ok;
        {aborted, Reason} ->
            io:format("Failed to create table: ~p~n", [Reason])
    end,
    {ok, #{}}.


% API
log(UserID, Record) ->
    gen_server:call(?MODULE, {log, UserID, Record}).

last(UserID, Count) ->
    gen_server:call(?MODULE, {last, UserID, Count}).

dump(UserID) ->
    gen_server:call(?MODULE, {dump, UserID}).



% Callbacks
handle_call({log, UserID, Record}, _From, State) ->
    case mnesia:transaction(fun() ->
        case mnesia:read({history, UserID}) of 
            [] ->
                mnesia:write({history, UserID, [Record]}),
                {ok, added_new_log};
            [{history, UserID, Records}] ->
                NewRecords = [Record | Records],
                mnesia:write({history, UserID, NewRecords}),
                {ok, added_log}
        end
    end) of 
        {atomic, Result} -> {reply, Result, State};
        {aborted, Reason} -> {reply, {error, Reason}, State}
    end;


handle_call({last, UserID, Count}, _From, State) when is_integer(Count) ->
    case mnesia:transaction(fun() -> 
        mnesia:read({history, UserID})    
    end) of
        {atomic, []} -> 
            {reply, {error, not_found}, State};
        {atomic, [{history, UserID, Records}]} -> 
            LastNRecords = lists:sublist(Records, Count),
            {reply, {ok, LastNRecords}, State};
        {aborted, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call({dump, UserID}, _From, State) -> 
    case mnesia:transaction(fun() ->
        mnesia:read({history, UserID})
    end) of
        {atomic, []} ->
            {reply, {error, not_found}, State};
        {atomic, [{history, UserID, Records}]} ->
            {reply, {ok, Records}, State};
        {aborted, Reason} ->
            {reply, {error, Reason}, State}
    end;


handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.


handle_cast(_Msg, Store) ->
    {noreply, Store}.

handle_info(_Info, Store) ->
    {noreply, Store}.

terminate(_Reason, _Store) ->
    ok.

code_change(_OldVsn, Store, _Extra) ->
    {ok, Store}.



