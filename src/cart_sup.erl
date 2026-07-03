-module(cart_sup).
-behaviour(supervisor).

-export([start_link/0, init/1, add_cart/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

add_cart(UserID) ->
    supervisor:start_child(?MODULE, [UserID]).


init([]) ->
    Children = [
        #{
            id => cart,
            start => {cart, start_link, []},
            restart => permanent,
            shudtodwn => 5000,
            type => worker,
            modules => [cart]
        }
    ],
    {ok, {{simple_one_for_one, 5, 10}, Children}}.