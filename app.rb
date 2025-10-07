# TODO
# - green for positive, red for negative
# - Display mode: table or big font
# - configuration file .config/...
#    - display_mode
#    - colors
#    - refresh rate
#    - stocks
#    - currencies
#    - cryptocurrencies
# - display_mode as command argument and crypto / stocks
# - Encapsulate in a binary
# - Add tests
# - Kill with CTRL + C

require 'net/http'
require 'uri'
require 'json'
require 'curses'
require 'hawktui/streaming_table'
load 'configuration.rb'
load 'currencies.rb'

config = Configuration.new({})

def number_with_delimiter(number)
  number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
end

# Handle CTRL+C
trap("INT") do
  Curses.close_screen
  exit
end

# Create the streaming table with columns
columns = [
  { name: 'Asset', width: 40 },
  { name: 'Value', width: 20 }
]
table = Hawktui::StreamingTable.new(columns: columns, max_rows: 50)
table.start

# Start a thread to fetch and update data
Thread.new do
  loop do
    break if table.should_exit

    # Clear previous rows
    table.instance_variable_set(:@rows, [])
    data = Currencies.load(config)

    crypto_values = {}

    config.cryptos_list.each do |row|
      if data[row]
        crypto_values[row] = data[row]
        table.add_row('Asset' => row.capitalize, 'Value' => number_with_delimiter(crypto_values[row]['usd'].to_i).rjust(20))
      end
    end

    config.currencies_list.each do |map|
      from, to = map.split('/')
      first_crypto = crypto_values.values.first
      if first_crypto
        rate = first_crypto[to].to_f / first_crypto[from].to_f
        table.add_row('Asset' => "#{from.upcase}/#{to.upcase}", 'Value' => number_with_delimiter(rate.round(2)).rjust(20))
      end
    end

    # Sleep in small increments to check for exit more frequently
    60.times do
      sleep 1
      break if table.should_exit
    end
  end
end

# Keep the main thread alive, checking for exit frequently
loop do
  sleep 0.1
  break if table.should_exit
end
