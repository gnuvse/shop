-module(catalog).
-behaviour(gen_server).



-export([start_link/0, add_item/3, update/3, update/2, get/1, dump/0, checkout/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
    terminate/2, code_change/3]).


-spec add_item(string(), float(), integer()) -> {ok, tuple()} | {error, term()}.
-spec update(string(), float(), integer()) -> {ok, tuple()} | {error, term()}.
-spec get(string()) -> {ok, tuple()} | {error, term()}.
-spec dump() -> list(tuple()).
-spec checkout(string(), integer()) -> {ok, integer()} | {error, insufficient_stock | not_found}.


init([]) ->
    mnesia:create_schema([node()]),
    case mnesia:system_info(is_running) of
        no -> mnesia:start();
        yes -> ok
    end,
    case mnesia:create_table(catalog, [
        {attributes, [name, price, stock]},
        {disc_copies, [node()]}
    ]) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, catalog}} -> ok
    end,
    {ok, #{}}.


start_link() ->
    % {local, ?MODULE} registred on this node()
    % ?MODULE where is it looking for behaviour gen_server?
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


    
% API
add_item(Name, Price, Stock) ->
    gen_server:call(?MODULE, {add, Name, Price, Stock}).

update(Name, Price, Stock) ->
    gen_server:call(?MODULE, {add, Name, Price, Stock}).

update(Name, Price) ->
    gen_server:call(?MODULE, {update_price, Name, Price}).

get(Name) ->
    gen_server:call(?MODULE, {get, Name}).

dump() ->
    gen_server:call(?MODULE, dump).

checkout(Name, Quantity) ->
    gen_server:call(?MODULE, {checkout, Name, Quantity}).


% CallBacks

handle_call({add, Name, Price, Stock}, _From, State) when is_list(Name), 
    is_integer(Stock), is_number(Price), Price >= 1, Stock >= 0 ->
    case mnesia:transaction(fun() ->
            mnesia:write({catalog, Name, Price, Stock}),
            {ok, added_new}
        end) of 
        {atomic, Result} -> {reply, Result, State};
        {aborted, Reason} -> {reply, {error, Reason}, State}
    end;


handle_call({add, _Name, Price, Stock}, _From, State) ->
    {reply, {error, {wrong_data, Price, Stock}}, State};


handle_call({update_price, Name, NewPrice}, _From, State) when is_list(Name), is_number(NewPrice), NewPrice >= 1 ->
    case mnesia:transaction(fun() ->
        case mnesia:read({catalog, Name}) of 
            [{catalog, Name, _OldPrice, Stock}] ->
                mnesia:write({catalog, Name, NewPrice, Stock}),
                ok;
            [] -> 
                {error, not_found}
        end
    end) of 
        {atomic, Result} -> {reply, Result, State};
        {aborted, Reason} -> {reply, {error, Reason}, State}
    end;


handle_call({update_price, Name, Price}, _From, State) ->
    {reply, {error, {wrong_price, Name, Price}}, State};

handle_call({get, Name}, _From, State) ->
    case mnesia:transaction(fun() -> mnesia:read({catalog, Name}) end) of 
        {atomic, []} -> 
            {reply, {error, not_found}, State};
        {atomic, [{catalog, Name, Price, Stock}]} -> 
            {reply, {ok, {Price, Stock}}, State};
        {aborted, Reason} -> 
            {reply, {error, Reason}, State}
    end;


handle_call(dump, _From, State) ->
    case mnesia:transaction(fun() -> 
        mnesia:foldl(fun(Rec, Acc) -> [Rec | Acc] end, [], catalog) end) 
        of  
        {atomic, Items} -> {reply, {ok, Items}, State};
        {aborted, Reason} -> {reply, {error, Reason}, State}
    end;


handle_call({checkout, Name, Quantity}, _From, State) 
  when is_list(Name), is_number(Quantity), Quantity > 0 ->
    case mnesia:transaction(fun() ->
        case mnesia:read({catalog, Name}) of
            [] -> {error, not_found};
            [{catalog, Name, Price, Stock}] when Stock >= Quantity ->
                NewStock = Stock - Quantity,
                mnesia:write({catalog, Name, Price, NewStock}),
                {ok, NewStock};
            [{catalog, _Name, _Price, Stock}] ->
                {error, {insufficient_stock, Stock}}
        end
    end) of 
        {atomic, Result} -> {reply, Result, State};
        {aborted, Reason} -> {reply, {error, Reason}, State}
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

