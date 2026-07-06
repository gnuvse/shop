-module(catalog_tests).
-include_lib("eunit/include/eunit.hrl").

setup() ->
    mnesia:stop(),
    mnesia:delete_schema([node()]),
    mnesia:create_schema([node()]),
    mnesia:start(),
    {ok, _Pid} = catalog:start_link(),
    mnesia:wait_for_tables([catalog], 5000),
    ok.

cleanup() ->
    gen_server:stop(catalog),
    mnesia:stop().

add_updat_item_test() ->
    setup(),
    ?assertEqual({ok, added_new}, catalog:add_item("apple", 100, 100)),
    ?assertEqual({ok, {100, 100}}, catalog:get("apple")),
    ?assertEqual({ok, added_new}, catalog:add_item("apple", 10, 1)),
    ?assertEqual({ok, {10, 1}}, catalog:get("apple")),
    ?assertEqual({ok, added_new}, catalog:add_item("pineapple", 100, 100)),
    ?assertEqual({ok, {100, 100}}, catalog:get("pineapple")),
    ?assertEqual({ok, added_new}, catalog:add_item("pineapple", 10, 1)),
    ?assertEqual({ok, {10, 1}}, catalog:get("pineapple")),

    cleanup().


add_item_wrong_test() ->
    setup(),
    ?assertEqual({error,{wrong_data, 0.2, 0.2}},    catalog:add_item("apple", 0.2, 0.2)),
    ?assertEqual({error,{wrong_data, 1, 0.2}},      catalog:add_item("apple", 1, 0.2)),
    ?assertEqual({error,{wrong_data,  0.2, 0.1}},   catalog:add_item("apple", 0.2, 0.1)),
    ?assertEqual({error,{wrong_data,  0.2, 0.1}},   catalog:add_item("apple", 0.2, 0.1)),
    ?assertEqual({error,{wrong_data,  0.2, 0.1}},   catalog:add_item("apple", 0.2, 0.1)),
    ?assertEqual({error,{wrong_data,  0.2, 0.1}},   catalog:add_item("apple", 0.2, 0.1)),
    ?assertEqual({error,{wrong_data,  0.2, 0}},     catalog:add_item("apple", 0.2, 0)),
    ?assertEqual({error,{wrong_data,  0, -1}},      catalog:add_item("apple", 0, -1)),
    ?assertEqual({error,{wrong_data,  -1, -1}},     catalog:add_item("apple", -1, -1)),
    ?assertEqual({error,{wrong_data,  -1, 1}},      catalog:add_item("apple", -1, 1)),
    ?assertEqual({error,{wrong_data,  1, 0.1}},     catalog:add_item("apple", 1, 0.1)),
    cleanup().


change_price_test() ->
    setup(),
    ?assertEqual({ok, added_new}, catalog:add_item("apple", 100, 100)),
    ?assertEqual({ok, {100, 100}}, catalog:get("apple")),
    ?assertEqual(ok, catalog:update("apple", 1000)),
    ?assertEqual({ok, {1000, 100}}, catalog:get("apple")),
    cleanup().   


change_wrong_price_test() ->
    setup(),
    ?assertEqual({ok, added_new}, catalog:add_item("apple", 100, 100)),
    ?assertEqual({error,{wrong_price, "apple", -1}},    catalog:update("apple", -1)),
    ?assertEqual({error,{wrong_price, "apple", 0.2}},    catalog:update("apple", 0.2)),
    ?assertEqual({error,{wrong_price, "www", -1}},    catalog:update("www", -1)),
    ?assertEqual({error,not_found},    catalog:update("www", 1)),
    cleanup().   


get_not_found_test() ->
    setup(),
    ?assertEqual({error,not_found}, catalog:get("ww")),
    ?assertEqual({error,not_found}, catalog:get(1)),
    ?assertEqual({error,not_found}, catalog:get(<<"pineapple">>)),
    ?assertEqual({error,not_found}, catalog:get([])),
    ?assertEqual({error,not_found}, catalog:get({})),
    ?assertEqual({error,not_found}, catalog:get(#{})),
    cleanup().  

checkout_ok_test() ->
    setup(),
    catalog:add_item("banana", 50, 10),
    ?assertEqual({ok, 5}, catalog:checkout("banana", 5)),
    ?assertEqual({ok, {50, 5}}, catalog:get("banana")),
    cleanup().    

checkout_insufficient_test() ->
    setup(),
    catalog:add_item("orange", 30, 3),
    ?assertEqual({error, {insufficient_stock, 3}}, catalog:checkout("orange", 10)),
    cleanup().   