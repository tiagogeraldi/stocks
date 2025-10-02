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
require 'io/console'
require 'ruby_figlet'
require 'colorize'
require 'terminal-table'
load 'configuration.rb'

config = Configuration.new({})

fiducial = config.currencies.flatten.each { |i| i.split('/') }.uniq

def print_big(text, color)
  font = 'big' # big, block or slant
  result = RubyFiglet::Figlet.new(text, font)
  result = result.to_s.lines.join("\r")
  puts result.to_s.lines.map(&:rstrip).join("\n").colorize(color)
end

def number_with_delimiter(number)
  number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
end

# Thread to listen for 'q' or 'Q' to quit
Thread.new do
  loop do
    char = STDIN.getch
    exit if char.downcase == 'q'
  end
end

rows = config.cryptos + config.currencies

initial_values = rows.map do |row|
  [row, 0.0 ]
end.to_h

result = {}

# Main loop to fetch and display data every 10 seconds
loop do
  # Fetch data from CoinGecko API
  puts config.cryptos
  puts fiducial
  uri = URI.parse("https://api.coingecko.com/api/v3/simple/price?ids=#{config.cryptos.join(',')}&vs_currencies=#{fiducial.join(',')}")
  response = Net::HTTP.get_response(uri)

  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    puts data
    crypto_values = {}

    config.cryptos.each do |row|
      if data[row]
        crypto_values[row] = data[row]
        result[row] = crypto_values[row]['usd'].to_i
      end
    end

    puts config.currencies
    config.currencies.each do |map|
      from, to = map.split('/')
      rate = crypto_values.values.first[to].to_f / crypto_values.values.first[from].to_f
      result["#{from}/#{to}"] = rate.round(2)
    end
  end

  print "\e[2J\e[H"

  if config.display_mode == 'table'
    table = Terminal::Table.new(
      title: 'Stocks',  # Optional: Adds a title above the table
      headings: ['Item', 'Value'],
      rows: result.to_a,
      style: { width: 50 }
    )
    table.align_column(1, :right)
    puts table.to_s.lines.map(&:rstrip).join("\r\n")
  else
    result.each do |key, value|
      puts key.upcase
      puts "\r"
      color = value >= initial_values[key] ? :green : :red
      print_big number_with_delimiter(value.to_f), color
      puts "\r"
    end
  end

  puts "\r"

  # Refresh rate
  sleep 60
end
