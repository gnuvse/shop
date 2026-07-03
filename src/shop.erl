-module(shop).
-behaviour(gen_server).


-export([init/1, handle_call/3, handle_cast/2, handle_info/2, 
    terminate/2, code_change/3]).


-export([start_link/0, add_user/2, login/2, logout/1, add_item/3, delete_item/2, checkout/1,
    get_user_cart/1, get_catalog/0, get_user_pids/1, get_state/0]).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    State = #{
        users => #{},
        carts => #{},
        tokens => #{},
        names => #{}    
    },
    {ok, State}.


-spec add_user(string(), string()) -> {ok, {atom(), string()}} | {error, term()}.
-spec login(string(), string()) -> {ok, binary()} | {error, wrong_password | user_not_found}.
-spec logout(binary()) -> {ok, {logout, binary()}} | {error, token_not_found}.
-spec add_item(binary(), string(), integer()) -> {ok, add_item} | {error, token_not_found}.
-spec delete_item(binary(), string()) -> {ok, delete_item} | {error, token_not_found}.
-spec get_user_cart(binary()) -> {ok, map()} | {error | term()}.
-spec get_catalog() -> {ok, map()}.
-spec checkout(binary()) -> {ok, list()} | {error, term()}.


-spec get_user_pids(string()) -> {ok, pid(), pid()} | {error, user_not_found}.
-spec get_state() -> {ok, map()}.



add_user(Name, Password) ->
    gen_server:call(?MODULE, {add_user, Name, Password}).

login(UserID, Password) ->
    gen_server:call(?MODULE, {login, UserID, Password}).

logout(Token) ->
    gen_server:call(?MODULE, {logout, Token}).

add_item(Token, Item, Quantity) ->
    gen_server:call(?MODULE, {add_item, Token, Item, Quantity}).

delete_item(Token, Item) ->
    gen_server:call(?MODULE, {delete_item, Token, Item}).

checkout(Token) ->
    gen_server:call(?MODULE, {checkout, Token}).

get_user_cart(Token) ->
    gen_server:call(?MODULE, {get_user_cart, Token}).

get_catalog() ->
    gen_server:call(?MODULE, get_catalog).

get_user_pids(UserID) ->
    gen_server:call(?MODULE, {get_user_pids, UserID}).

get_state() ->
    gen_server:call(?MODULE, get_state).




handle_call({add_user, Name, Password}, _From, State) when 
    is_list(Name), length(Name) > 0, length(Name) < 30 ->
    #{users := Users, carts := Carts, names := Names} = State,
    UserID = string:lowercase(Name) ++ "_" ++ integer_to_list(erlang:unique_integer([monotonic]) rem 10000),
    
    case maps:find(string:lowercase(Name), Names) of
        {ok, _ExistingUserId} ->
            {reply, {error, name_already_exists}, State};
        error ->
            case maps:find(UserID, Users) of 
                {ok, {UserPid, UserName, UserPassword}} ->
                    case is_process_alive(UserPid) of
                        true -> {reply, {error, user_is_busy}, State};
                        false ->
                            {ok, NewUserPid} = user_shop_sup:add_user(UserID, UserName, UserPassword),
                            NewUsers = maps:put(UserID, {NewUserPid, UserName, UserPassword}, Users),
                            {reply, {ok, user_recconect}, State#{users => NewUsers}}
                    end;
                error -> 
                    case cart_sup:add_cart(UserID) of
                        {ok, CartPid} ->
                            case user_shop_sup:add_user(UserID, Name, CartPid) of
                                {ok, UserPid} ->
                                    NewUsers = maps:put(UserID, {UserPid, Name, Password}, Users),
                                    NewCarts = maps:put(UserID, CartPid, Carts),
                                    NewNames = maps:put(string:lowercase(Name), UserID, Names),
                                    {reply, {ok, UserID}, State#{users => NewUsers, carts => NewCarts, names => NewNames}};
                                {error, _} ->
                                    {reply, {error, not_make_user}, State}
                            end;
                        {error, _} ->
                            {reply, {error, not_make_cart}, State}
                    end
            end
    end;


handle_call({login, UserID, Password}, _From, State) ->
    #{users := Users, tokens := Tokens} = State,
    case maps:find(UserID, Users) of 
        {ok, {_UserPid, _Name, UserPWD}} ->
            case Password =:= UserPWD of 
                true ->
                    Token = rand:uniform(9999),
                    NewTokens = maps:put(Token, UserID, Tokens),
                    {reply, {ok, Token}, State#{tokens => NewTokens}};
                false ->
                    {reply, {error, wrong_password}, State}
            end;
        error ->
            io:format("DEBUG: ~p~n", [State]),
            {reply, {error, user_not_found}, State}
    end;


handle_call({logout, Token}, _From, State) ->
    #{users := _Users, tokens := Tokens} = State,
    case maps:find(Token, Tokens) of
        {ok, UserID} -> 
            NewTokens = maps:remove(Token, Tokens),
            io:format("DEBUG_LOGOUT_USER: ~p~n", [State]),
            {reply, {ok, {logout, UserID}}, State#{tokens=>NewTokens}};
        error ->
            io:format("DEBUG_LOGOUT_TNF: ~p~n", [State]),
            {reply, {error, {token_not_found, Token}}, State}
    end;


handle_call({add_item, Token, Item, Quantity}, _From, State) ->
    #{carts := Carts, tokens := Tokens} = State,

    case maps:find(Token, Tokens) of
        {ok, UserID} ->
            {ok, CartPid} = maps:find(UserID, Carts),
            case cart:add_item(CartPid, Item, Quantity) of 
                {error, Reason} -> {reply, {error, Reason}, State};
                {ok, added} ->
                    {reply, {ok, add_item}, State}
            end;
        error ->
            {reply, {error, not_found_token}, State}
    end;


handle_call({delete_item, Token, Item}, _From, State) ->
    #{carts := Carts, tokens := Tokens} = State,

    case maps:find(Token, Tokens) of
        {ok, UserID} ->
            {ok, CartPid} = maps:find(UserID, Carts),
            case cart:delete_item(CartPid, Item) of
                {error, Reason} -> {reply, {error, Reason}, State};
                {ok, deleted} -> 
                    {reply, {ok, delete_item}, State}
            end;
        error ->
            {reply, {error, not_found_token}, State}
    end;


handle_call({checkout, Token}, _From, State) ->
    #{carts := Carts, tokens := Tokens} = State,

    case maps:find(Token, Tokens) of
        {ok, UserID} ->
            {ok, CartPid} = maps:find(UserID, Carts),
            case cart:checkout(CartPid) of 
                {error, Reason} -> {reply, {error, Reason}, State};
                {ok, Orders} -> {reply, {ok, Orders}, State}
            end;
        error ->
            {reply, {error, not_found_token}, State}
    end;

handle_call({get_user_cart, Token}, _From, State) ->
    #{carts := Carts, tokens := Tokens} = State,

    case maps:find(Token, Tokens) of
        {ok, UserID} ->
            {ok, CartPid} = maps:find(UserID, Carts),
            case cart:get_cart(CartPid) of 
                {error, Reason} -> {reply, {error, Reason}, State};
                {ok, Cart} -> {reply, {ok, Cart}, State}
            end;
        error ->
            {reply, {error, not_found_token}, State}
    end;

handle_call({get_user_pids, UserID}, _From, State) ->
    #{users := Users, carts := Carts} = State,
    case maps:find(UserID, Users) of
        {ok, {UserPid, _Password}} ->
            CartPid = maps:find(UserID, Carts),
            {reply, {ok, UserPid, CartPid}, State};
        error ->
            {reply, {error, not_found_user}, State}
    end;

handle_call(get_catalog, _From, State) ->
    case catalog:dump() of 
        {ok, Items} -> {reply, {ok, Items}, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end;

handle_call(get_state, _From, State) ->
    {reply, {ok, State}, State};

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