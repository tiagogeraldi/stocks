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
# - Add rubocop


require 'net/http'
require 'uri'
require 'json'
require 'io/console'
require 'ruby_figlet'
require 'colorize'

# see https://api.coingecko.com/api/v3/coins/list'
cryptos = ['bitcoin', 'ethereum', 'solana'] # load from config file
conversion_map = [%w[usd brl], %w[eur usd]] # load from config file

fiducial = conversion_map.flatten.uniq

def print_big(text, color)
  font = 'big' # big, block or slant
  result = RubyFiglet::Figlet.new(text, font)
  result = result.to_s.lines.join("\r")
  puts result.to_s.lines.map(&:rstrip).join("\n").colorize(color)
end

def number_with_delimiter(number)
  number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
end

trap('INT') do
  "\n#{puts('Exiting due to Ctrl+C...')}"
  exit
end

# Thread to listen for 'q' or 'Q' to quit
Thread.new do
  loop do
    char = STDIN.getch
    exit if char.downcase == 'q'
  end
end

rows = cryptos + conversion_map.map { |pair| pair.join('/') }

initial_values = rows.map do |row|
  [row, 0.0 ]
end.to_h

result = {}

# Main loop to fetch and display data every 10 seconds
loop do
  # Fetch data from CoinGecko API
  uri = URI.parse("https://api.coingecko.com/api/v3/simple/price?ids=#{cryptos.join(',')}&vs_currencies=#{fiducial.join(',')}")
  response = Net::HTTP.get_response(uri)

  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    crypto_values = {}
    puts data

    cryptos.each do |row|
      if data[row]
        crypto_values[row] = data[row]
        result[row] = crypto_values[row]['usd'].to_i
      end
    end

    conversion_map.to_h.each do |from, to|
      rate = crypto_values.values.first[to].to_f / crypto_values.values.first[from].to_f
      result["#{from}/#{to}"] = rate.round(2)
    end
  end

  print "\e[2J\e[H"

  result.each do |key, value|
    puts key.upcase
    puts "\r"
    color = value >= initial_values[key] ? :green : :red
    print_big number_with_delimiter(value.to_f), color
    puts "\r"
    puts "\r"
  end

  # Refresh rate
  sleep 60
end
