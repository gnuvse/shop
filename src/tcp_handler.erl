-module(tcp_handler).
-export([start_server/1]).


start_server(Port) ->
    {ok, ListenSocket} = gen_tcp:listen(Port, [binary, {active, false}, {reuseaddr, true}]),
    io:format("Shop listening on port ~p~n", [Port]),
    accept_loop(ListenSocket).


accept_loop(ListenSocket) ->
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    spawn(fun() -> client_loop(Socket) end),
    accept_loop(ListenSocket).


client_loop(Socket) ->
    Greetings = "\r\nWelcome to the Shop!\r\n",

    gen_tcp:send(Socket, list_to_binary(Greetings)),
    gen_tcp:send(Socket, list_to_binary(help_fun())),
    Limits = #{registrations => 0},

    loop_user(Socket, unauthenticated, Limits).


help_fun() ->
    Help = 
        "Commands | Arguments               | Description \r\n" ++
        "\n" ++
        "REGISTER   Name Password           - to get UserID\r\n" ++
        "LOGIN      UserID Password         - to get Token\r\n" ++
        "ADD        Token NameItem Quantity - to add item\r\n" ++
        "CART       Token                   - to check cart\r\n" ++
        "CHEKOUT    Token                   - to checkout you order\r\n" ++
        "CATALOG    not_arguments           - to check catalog\r\n" ++
        "LOGOUT     Token                   - to get Token\r\n" ++
        "HELP       mot_arguemnts           - to Help\r\n",
    Help.


loop_user(Socket, AuthState, Limits) ->
    case read_line(Socket, <<>>) of
        {ok, Line} ->
            CleanLine = binary:replace(Line, [<<"\r\n">>, <<"\n">>], <<>>),

            Command = binary:split(CleanLine, <<" ">>, [global, trim_all]),

            {NewAuthState, NewLimits} = handle_command(Command, AuthState, Socket, Limits),

            io:format("DEBUG: NewAuthState=~p~s~n", [NewAuthState, "\r"]),
            loop_user(Socket, NewAuthState, NewLimits);
        {error, closed} ->
            io:format("Clien disconnected~n")
    end.


handle_command([<<"REGISTER">>, BinName, BinPassword], unauthenticated, Socket, 
    #{registrations := RegCount} = Limits) when RegCount < 3 ->
        register(BinName, BinPassword, Socket),
        NewLimits = Limits#{registrations => RegCount + 1},
        {unauthenticated, NewLimits};

handle_command([<<"REGISTER">>, _BinName, _BinPassword], unauthenticated, Socket, 
    #{registrations := RegCount} = Limits) when RegCount =:= 3 ->
        gen_tcp:send(Socket, <<"ERROR: Too many registrations\r\n">>),
        {unauthenticated, Limits};


handle_command([<<"REGISTER">>, _BinName, _BinPassword], authenticated, Socket, Limits) ->
    gen_tcp:send(Socket, <<"ERROR: You already registred\r\n">>),
    {authenticated, Limits};


% handle_command([<<"REGISTER">>, _, _], _, Socket) ->
%     gen_tcp:send(Socket, <<"ERROR: Registerd failed\n">>);


handle_command([<<"LOGIN">>, BinUserID, BinPassword], unauthenticated, Socket, Limits) ->
    {login(BinUserID, BinPassword, Socket), Limits};

handle_command([<<"LOGIN">>, _BinUserID, _BinPassword], authenticated, Socket, Limits) ->
    gen_tcp:send(Socket, <<"ERROR: You already loggined\r\n">>),
    {authenticated, Limits};

handle_command([<<"HELP">>], Auth, Socket, Limits) ->
    help(Socket),
    {Auth, Limits};

handle_command(_, unauthenticated, Socket, Limits) ->
    gen_tcp:send(Socket, <<"ERROR: Please login first\r\n">>),
    {unauthenticated, Limits};


handle_command([<<"ADD">>, BinToken, BinNameItem, BinQuantity], authenticated, Socket, Limits) ->
    {add_item(BinToken, BinNameItem, BinQuantity, Socket), Limits};

handle_command([<<"CART">>, BinToken], authenticated, Socket, Limits) ->
    {get_cart(BinToken, Socket), Limits};

handle_command([<<"CHECKOUT">>, BinToken], authenticated, Socket, Limits) ->
    {checkout(BinToken, Socket), Limits};

handle_command([<<"CATALOG">>], authenticated, Socket, Limits) ->
    {catalog(Socket), Limits};

handle_command([<<"LOGOUT">>, BinToken], authenticated, Socket, Limits) ->
    {logout(BinToken, Socket), Limits};

handle_command(_, authenticated, Socket, Limits) ->
    gen_tcp:send(Socket, <<"ERROR: Wrong command\r\n">>),
    {authenticated,Limits}.


register(BinName, BinPassword, Socket) ->
    case shop:add_user(binary_to_list(BinName), binary_to_list(BinPassword)) of
        {ok, Login} -> 
            % ClearLogin = binary:replace(Login, [<<"\r\n">>, <<"\n">>], <<>>)
            gen_tcp:send(Socket, <<"Registration successful! Please LOGIN with your UserID and password.\r\n">>),
            gen_tcp:send(Socket, <<"Your login: ", (list_to_binary(Login))/binary, "\r\n">>),
            unauthenticated;
        {error, Reason} ->
            gen_tcp:send(Socket, <<"ERROR: ", (list_to_binary(io_lib:format("~p", [Reason])))/binary, "\r\n">>),
            unauthenticated
    end.


login(BinUserId, BinPassword, Socket) ->
    case shop:login(binary_to_list(BinUserId), binary_to_list(BinPassword)) of
        {ok, Token} -> 
            gen_tcp:send(Socket, <<"Your Token: ", (integer_to_binary(Token))/binary, "\r\n">>),
            authenticated;
        {error, Reason} ->
            gen_tcp:send(Socket, <<"ERROR: ", (list_to_binary(io_lib:format("~p", [Reason])))/binary, "\r\n">>),
            unauthenticated
    end. 


add_item(BinToken, BinNameItem, BinQuantity, Socket) ->
    case shop:add_item(binary_to_integer(BinToken), binary_to_list(BinNameItem),
        binary_to_integer(BinQuantity)) of
            {ok, add_item} ->
                gen_tcp:send(Socket, <<(list_to_binary("OK, item added\r\n"))/binary>>),
                authenticated;
            {error, Reason} ->
                gen_tcp:send(Socket, <<"ERROR: ", (list_to_binary(io_lib:format("~p", [Reason])))/binary, "\r\n">>),
                unauthenticated
    end.


get_cart(BinToken, Socket) ->
    case shop:get_user_cart(binary_to_integer(BinToken)) of
        {ok, Cart} ->
            gen_tcp:send(Socket, <<"CART: ", (list_to_binary(io_lib:format("~p", [Cart])))/binary, "\r\n">>),
            authenticated;
         {error, Reason} ->
            gen_tcp:send(Socket, <<"ERROR: ", (list_to_binary(io_lib:format("~p", [Reason])))/binary, "\r\n">>),
            unauthenticated
    end.


checkout(BinToken, Socket) ->
    case shop:checkout(binary_to_integer(BinToken)) of
        {ok, Orders} ->
            gen_tcp:send(Socket, <<"ORDER: ", (list_to_binary(io_lib:format("~p", [Orders])))/binary, "\r\n">>),
            authenticated;
         {error, Reason} ->
            gen_tcp:send(Socket, <<"ERROR: ", (list_to_binary(io_lib:format("~p", [Reason])))/binary, "\r\n">>),
            unauthenticated
    end.


catalog(Socket) ->
    case shop:get_catalog() of
        {ok, Catalog} ->
            gen_tcp:send(Socket, <<"CATALOG: ", (list_to_binary(io_lib:format("~s~p", ["\r", Catalog])))/binary, "\r\n">>),
            authenticated;
         {error, Reason} ->
            gen_tcp:send(Socket, <<"ERROR: ", (list_to_binary(io_lib:format("~p", [Reason])))/binary, "\r\n">>),
            authenticated
    end.


logout(BinToken, Socket) ->
    case shop:logout(binary_to_integer(BinToken)) of
        {ok, Ok} ->
            gen_tcp:send(Socket, <<"LOGOUT: ", (list_to_binary(io_lib:format("~p", [Ok])))/binary, "\r\n">>),
            unauthenticated;
         {error, Reason} ->
            gen_tcp:send(Socket, <<"ERROR: ", (list_to_binary(io_lib:format("~p", [Reason])))/binary, "\r\n">>),
            unauthenticated
    end.


help(Socket) ->
    gen_tcp:send(Socket, list_to_binary(help_fun())),
    unauthenticated.


read_line(Socket, Acc) ->
    case gen_tcp:recv(Socket, 1) of 
        {ok, <<"\n">>} -> {ok, <<Acc/binary, "\n">>};
        {ok, Byte} -> read_line(Socket, <<Acc/binary, Byte/binary>>);
        {error, closed} -> {error, closed}
    end.