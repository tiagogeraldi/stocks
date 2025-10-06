# Stocks

A Terminal app to watch stocks and currencies. It's designed for Hyprland and Omarchy but works in any terminal.

## Setup

```sh
bin/setup
```

Ensure you have ruby and bundler installed.

## Configuration

The Setup creates the file `~/.conf/stocks/stocks.conf`. It contains the following:

```conf
# see https://api.coingecko.com/api/v3/coins/list'
cryptos_list=bitcoin
currencies_list=usd/brl,eur/usd
stocks_list=apple,google

crypto_only=false
stocks_only=false
currency_only=false
```

Edit the file to inform the stocks, currencies, and cryptos you want to watch.

## Running

```sh
bin/run
```
