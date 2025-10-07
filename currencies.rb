class Currencies
  def self.load(config)
    fiducial = config.currencies_list.map { |i| i.split('/') }.flatten.uniq

    # Fetch data from CoinGecko API
    uri = URI.parse("https://api.coingecko.com/api/v3/simple/price?ids=#{config.cryptos_list.join(',')}&vs_currencies=#{fiducial.join(',')}")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      return JSON.parse(response.body)
    end
  end
end
