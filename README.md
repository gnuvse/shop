# TCP Shop

Учебный магазин на Erlang/OTP с telnet-интерфейсом.

## Запуск

rebar3 compile
rebar3 shell
tcp_handler:start_server(8080).

## Команды

| Команда | Аргументы | Описание |
|---------|-----------|----------|
| REGISTER | Name Password | Регистрация |
| LOGIN | UserID Password | Вход |
| ADD | Token Item Quantity | Добавить в корзину |
| CART | Token | Просмотр корзины |
| CHECKOUT | Token | Оформить заказ |
| CATALOG | - | Просмотр каталога |
| LOGOUT | Token | Выход |
| HELP | - | Справка |


## Тестовые данные
В проекте уже есть каталог товаров:
- apple,  price=999.0, stock=70
- banana, price=500,   stock=100
- orange, price=250,   stock=100
