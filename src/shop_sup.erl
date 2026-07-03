-module(shop_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    Children = [
        #{
            id => history,
            start => {history, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [history]
        },
        #{
            id => catalog,
            start => {catalog, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [catalog]
        }, 
        #{
            id => shop,
            start => {shop, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [shop]
        }, 
        #{
            id => user_shop_sup,
            start => {user_shop_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [user_shop_sup]            
        },
        #{
            id => cart_sup,
            start => {cart_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [cart_sup]            
        },
        #{
            id => tcp_handler,
            start => {tcp_handler, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [tcp_handler]            
        }
    ],
    {ok, {{one_for_one, 5, 10}, Children}}.