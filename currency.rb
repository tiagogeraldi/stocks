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
require 'cli/ui'
require 'tty-reader'
load 'configuration.rb'

reader = TTY::Reader.new

# Event listener for keypress events
reader.on(:keypress) do |event|
  if event.value.downcase == 'q'
    CLI::UI.puts "\nQ pressed! Exiting..."
    exit
  else
    CLI::UI.puts "\nKey '#{event.value}' pressed. Press Q to quit."
    reader.read_keypress
  end
end



CLI::UI::StdoutRouter.enable
CLI::UI.frame_style = :bracket
config = Configuration.new({})

fiducial = config.currencies_list.map { |i| i.split('/') }.flatten.uniq

def number_with_delimiter(number)
  number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
end


# rows = config.cryptos_list + config.currencies_list

# initial_values = rows.map do |row|
#   [row, 0.0 ]
# end.to_h

# Listen for key press without blocking the main loop
if IO.console.ready?
  char = IO.console.getch
  exit if char.downcase == 'q'
end

loop do
  # Clear screen and move cursor to top-left for refresh effect
  print "\e[2J\e[H"

  crypts = []
  currs = []
  stocks = []

  CLI::UI::Frame.open('{{*}} {{bold:Stocks}}', color: :green) do
    # Fetch data from CoinGecko API
    uri = URI.parse("https://api.coingecko.com/api/v3/simple/price?ids=#{config.cryptos_list.join(',')}&vs_currencies=#{fiducial.join(',')}")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      crypto_values = {}

      config.cryptos_list.each do |row|
        if data[row]
          crypto_values[row] = data[row]
          crypts << [row, number_with_delimiter(crypto_values[row]['usd'].to_i)]
        end
      end

      config.currencies_list.each do |map|
        from, to = map.split('/')
        rate = crypto_values.values.first[to].to_f / crypto_values.values.first[from].to_f
        currs << [ "#{from}/#{to}".upcase, number_with_delimiter(rate.round(2)) ]
      end
    end

    if crypts.any?
      CLI::UI::Frame.divider('Crypto')
      CLI::UI::Table.puts_table(crypts, col_spacing: 4)
    end

    if currs.any?
      CLI::UI::Frame.divider('Currencies')
      CLI::UI::Table.puts_table(currs, col_spacing: 4)
    end

    if stocks.any?
      CLI::UI::Frame.divider('Stocks')
      CLI::UI::Table.puts_table(stocks, col_spacing: 4)
    end
  end

  reader.read_keypress

  sleep 60
end

CLI::UI.puts "Goodbye!"
