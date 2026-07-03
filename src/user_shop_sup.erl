-module(user_shop_sup).
-behaviour(supervisor).


-export([start_link/0, init/1, add_user/3]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

add_user(UserID, Name, CartPid) ->
    supervisor:start_child(?MODULE, [UserID, Name, CartPid]).

init([]) ->
    Children = [
        #{
            id => user,
            start => {user, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [user]    
        }    
    ],
    {ok, {{simple_one_for_one, 5, 10}, Children}}.
