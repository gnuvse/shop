-module(user).
-behaviour(gen_server).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, 
    terminate/2, code_change/3]).

-export([start_link/3, display_name/1, get_cart_pid/1]).


-spec display_name(pid()) -> {ok, string()} | {error | term()}.
-spec get_cart_pid(pid()) -> {ok, pid()} | {error | term()}.


start_link(UserID, Name, CartPid) ->
    gen_server:start_link(?MODULE, [UserID, Name, CartPid], []).


init([UserID, Name, CartPid]) ->
    State = #{
        name => Name,
        user_id => UserID,
        cart_pid => CartPid,
        balance => 0.0        
    },
    {ok, State}.


display_name(UserPid) ->
    gen_server:call(UserPid, display_name).

get_cart_pid(UserPid) ->
    gen_server:call(UserPid, get_cart_pid).


handle_call(display_name, _From, State) ->
    #{name := Name} = State,
    {reply, {ok, Name}, State};


handle_call(get_cart_pid, _From, State) ->
    #{cart_pid := Pid} = State,
    {reply, {ok, Pid}, State};


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


% handle_call({add_user, Name}, _From, State) when is_list(Name) ->
%     UserID = string:lowercase(Name) ++ "_" ++ integer_to_list(erlang:unique_integer()),
%     case cart_sup:add_cart(UserID) of 
%         {ok, Pid} ->
%             NewState = #{
%                 name => Name,
%                 user_id => UserID,
%                 cart_pid => Pid
%             }, 
%             {reply, {ok, UserID, Pid}, NewState};
%         {error, Reason} ->
%             {reply, {error, Reason}, State}
%     end;



% handle_call({add_user, Name}, _From, State) -> 
%     {reply, {error, {bad_name_arg, Name}}, State};
