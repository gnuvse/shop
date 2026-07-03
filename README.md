# TCP Shop

Учебный магазин на Erlang/OTP с telnet-интерфейсом.

## Архитектура
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

## Запуск
 - Server

rebar3 compile
rebar3 shell
tcp_handler:start_server(8080).

 - Client (Win)
telnet localhost 8080


## Команды
REGISTER Name Password      - регистрация
LOGIN UserID Password       - вход
ADD Token Item Quantity     - добавить в корзину
CART Token                  - посмотреть корзину
CHECKOUT Token              - оформить заказ
CATALOG                     - посмотреть каталог
LOGOUT Token                - выход
HELP                        - справка


## Тестовые данные
В проекте уже есть каталог товаров:
- apple,  price=999.0, stock=70
- banana, price=500,   stock=100
- orange, price=250,   stock=100