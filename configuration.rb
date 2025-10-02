class Configuration

  attr_reader :display_mode, :cryptos_list, :currencies_list, :stocks_list,
              :crypto_only, :stocks_only, :currency_only, :config_file

  def initialize(args)
    @args = args
    load_config_file
    load_variables
  end

private

  def load_config_file
    @config_file = @args[:config_file]

    unless @config_file
      if File.exist?("~/.config/stocks/stocks.conf")
        @config_file = "~/.config/stocks/stocks.conf"
      else
        @config_file = "stocks.conf"
      end
    end
  end

  def load_variables
    text = File.read(@config_file)
    data = text.scan(/(\w+)\s*=\s*"?([^"\n]+)"?/)

    Hash[data].merge(@args).each do |key, value|
      parsed_value = key.include?('_list') ? value.split(',') : value
      instance_variable_set("@#{key}", parsed_value)
    end
  end
end
