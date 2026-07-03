-module(cart).
-behaviour(gen_server).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, 
    terminate/2, code_change/3]).

-export([start_link/1, add_item/3, delete_item/2, get_cart/1, checkout/1]).


start_link(UserID) ->
    gen_server:start_link(?MODULE, [UserID], []).


init([UserID]) ->
    State = #{
        user_id => UserID,
        items => #{},
        cost => 0.0,
        order_id => 0
    },
    {ok, State}.

-record(order, {
        id,
        user_name,
        item_name, 
        price,
        quantity,
        timestamp
    }).

-spec add_item(pid(), string(), integer()) -> {ok, term()} | {error, term()}.
-spec delete_item(pid(), string()) -> {ok, term()} | {error, term()}.
-spec get_cart(pid()) -> {ok, map()} | {error, term()}.
-spec checkout(pid()) -> {ok, #order{}} | {error, term()}.



% API

add_item(PidCart, Item, Quantity) ->
    gen_server:call(PidCart, {add_item, Item, Quantity}).


delete_item(PidCart, Item) ->
    gen_server:call(PidCart, {delete_item, Item}).


get_cart(PidCart) ->
    gen_server:call(PidCart, get_cart).


checkout(PidCart) ->
    gen_server:call(PidCart, checkout).


% CallBacks
handle_call(checkout, _From, State) ->
    #{user_id := UserID, items := Items, order_id := OrderID} = State,
  
    case map_size(Items) =:= 0 of 
        true -> {reply, {error, cart_is_empty}, State};
        false ->
            % Проверка остатоков конкретного товара на складе и его существование
            Fun = fun(Item, Quantity, Acc) -> 
                case catalog:get(Item) of 
                    {ok, {Price, Stock}} when Stock >= Quantity ->
                        maps:put(Item, {ok, Price, Quantity}, Acc);
                    {error, _Reason} ->
                        Acc
                end
            end,
            OkItems = maps:fold(Fun, #{}, Items),

            % Количество проверенного товара равна количеству товара в корзине
            case maps:size(OkItems) =:= maps:size(Items) of 
                true -> 
                    % отлавливаем ошибку, если catalog:chekout вернул ее, либо создаем заказ и логгируем его, 
                    % накапливая дальнейшую проверку
                    CheckoutResult = 
                        try maps:fold(fun(Item, {ok, Price, Quantity}, Acc) ->
                            case catalog:checkout(Item, Quantity) of
                                {ok, _NewStock} ->
                                    NewOrder = #order {
                                        id = OrderID + 1,
                                        user_name = UserID,
                                        item_name = Item, 
                                        price = Price,
                                        quantity = Quantity,
                                        timestamp = erlang:system_time(second)
                                    },
                                    history:log(UserID, NewOrder),
                                    [NewOrder | Acc];
                                {error, Reason} ->
                                    throw({checkout_failed, Item, Reason})
                            end
                    end, [], OkItems)
                    catch 
                        throw:{checkout_failed, FailedItem, FailedReason} -> {checkout_failed, FailedItem, FailedReason};
                        _:Other -> {error, Other}
                    end,
                    case CheckoutResult of 
                        {checkout_failed, Item, Reason} -> {reply, {error, {Item, Reason}}, State};
                        Orders -> {reply, {ok, Orders}, State#{items => #{}, order_id=>OrderID + 1}}
                    end;
                false ->
                    {reply, {error, insufficient_stock}, State}
            end
    end;



handle_call(get_cart, _From, State) ->
    #{items := Items} = State,
    {reply, {ok, Items}, State};

handle_call({add_item, Item, Quantity}, _From, State) when is_number(Quantity), Quantity > 0 ->
    #{items := Items} = State,

    case catalog:get(Item) of 
        {error, not_found} ->
            {reply, {error, {not_found_item, Item}}, State};
        {ok, {_Price, Stock}} when Stock >= Quantity -> 
            NewItems = maps:update_with(Item, fun(Old) -> Old + Quantity end, Quantity, Items),
            {reply, {ok, added}, State#{items => NewItems}};
        {ok, {_Price, Stock}} ->
            {reply, {error, {not_enough_stock, Item, Stock, Quantity}}, State};
        {error, Reason} -> 
            {reply, {error, Reason}, State}
    end;

handle_call({add_item, _Item, Quantity}, _From, State) when Quantity =< 0 ->
    {reply, {error, quantity_must_be_positive}, State};

handle_call({delete_item, Item}, _From, State) when length(Item) > 0, length(Item) =< 30 ->
    #{items := Items} = State,
    case catalog:get(Item) of 
        {error, not_found} ->
            {reply, {error, {not_found_item, Item}}, State};
        {ok, {_Price, _Stock}}  -> 
            NewItems = maps:remove(Item, Items),
            {reply, {ok, deleted}, State#{items => NewItems}};
        {error, Reason} -> 
            {reply, {error, Reason}, State}
    end;
    

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


% cart.erl
% % MyAPI
% add_item(PidCart,Item, Quantity) -> {ok, term()} | {error, term()}
% delete_item(PidCart,Item, Quantity) -> {ok, term()} | {error, term()}
% get_cart(PidCart) -> {ok, list()} | {error, term()}
% checkout(PidCart) -> {ok, #order{}} | {error, term()}