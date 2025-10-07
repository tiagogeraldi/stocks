class Stocks
  BASE_URL = 'https://query1.finance.yahoo.com'

  def self.load(config)
    symbols = config.stocks_list(&:upcase).join(',')

    uri = URI.parse("#{BASE_URL}/v7/finance/quote")
    uri.query = URI.encode_www_form({
      'symbols' => symbols
    })

    result = {}
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      results = data['quoteResponse']['result']

      if results && !results.empty?
        results.each do |quote|
          symbol = quote['symbol']
          price = quote['regularMarketPrice']
          result[symbol] = price
        end
      else
        puts response.body
      end
    end

    result
  end
end
