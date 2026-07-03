shop_app
  └── shop_sup (one_for_one)
         ├── catalog (worker)
         ├── history (worker)
         ├── user_sup (simple_one_for_one)
         │      ├── user "Alice"
         │      └── user "Bob"
         ├── cart_sup (simple_one_for_one)
         │      ├── cart "Alice"
         │      └── cart "Bob"
         ├── shop (worker)
         └── tcp_handler (worker)

% AI
Команды 

Telnet → tcp_handler → gen_server:call(shop, {...}) → shop вызывает catalog/cart/history → ответ → tcp_handler → Telnet




Проект: Корзина товаров (TCP-Shop)
Суть: магазин с каталогом, корзинами пользователей и оформлением заказов.

Команды telnet:

text
LOGIN Alice
LIST                          — список товаров
ADD Alice item123 2           — добавить 2 единицы в корзину
CART Alice                    — содержимое корзины
CHECKOUT Alice                — оформить заказ (списать stock, записать в лог)
Требования:

Каталог товаров: #{id => {name, price, stock}}

Корзина пользователя: {user, [{item_id, quantity}]}

История заказов: хранить в Mnesia

TCP-сервер принимает команды и возвращает ответы

При оформлении заказа: проверить наличие, списать stock, записать в лог, очистить корзину

Спроектируй:

Какие процессы (модули) нужны?

Дерево супервизоров

API между процессами

Формат ответов клиенту
% end AI

catalog.erl
% My API
add(Name, Price, Stock)
update(Name, Price, Stock)
get_item(Name/Id)
dump() 
delete(Name/Id)
checkout(Name/Id)

% My API redisigned AI
add(Name, Price, Stock) -> ok | {error, Reason}
update(Name, Price, Stock) -> ok | {error, Reason}
get(Name) -> {ok, Item} | {error, not_found}
delete(Name) -> ok
dump() -> [Items]
checkout(Name, Quantity) -> {ok, NewStock} | {error, insufficient | not_found}




history.erl
% My API
log(Name, Record) -> ok | {error, Reason}
last(Name, Record, Count) -> {ok, LastRecordsByCount} | {error, Reason}
dump(Name) -> {ok, NamesRecords} | {error, Reason}

-record(order, {
    id,
    user_name,
    item_name,
    price,
    quantity,
    timestamp,
    extra1,
    extra2
}).

cart.erl
% MyAPI
add_item(PidCart,Item, Quantity) -> {ok, term()} | {error, term()}
delete_item(PidCart,Item, Quantity) -> {ok, term()} | {error, term()}
get_cart(PidCart) -> {ok, list()} | {error, term()}
checkout(PidCart) -> {ok, #order{}} | {error, term()}


UserId = string:lowercase(Name) ++ "_" ++ integer_to_list(erlang:unique_integer()),