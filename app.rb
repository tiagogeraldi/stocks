#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'curses'

load 'configuration.rb'
load 'currencies.rb'
load 'stocks.rb'

# Stocks and Currencies Monitor - Display financial data in a TUI
class FinancialMonitor
  include Curses

  REFRESH_INTERVAL = 60 # seconds
  HEADER_HEIGHT = 3
  FOOTER_HEIGHT = 1

  def initialize(config)
    @config = config
    @running = true
    @scroll_offset = 0
    @data = []
  end

  def run
    init_screen
    start_color
    curs_set(0) # Hide cursor
    noecho
    cbreak

    # Define color pairs
    init_pair(1, COLOR_WHITE, COLOR_BLUE)   # Header
    init_pair(2, COLOR_GREEN, COLOR_BLACK)  # Positive/Normal
    init_pair(3, COLOR_YELLOW, COLOR_BLACK) # Warning
    init_pair(4, COLOR_RED, COLOR_BLACK)    # Negative
    init_pair(5, COLOR_CYAN, COLOR_BLACK)   # Footer
    init_pair(6, COLOR_MAGENTA, COLOR_BLACK) # Stocks

    begin
      loop do
        break unless @running

        # Fetch data
        fetch_data

        # Draw UI
        draw_ui

        # Non-blocking input check
        timeout_ms = REFRESH_INTERVAL * 1000 # milliseconds
        stdscr.timeout = timeout_ms

        case getch
        when 'q', 'Q'
          @running = false
        when 'r', 'R'
          # Force refresh
          next
        when KEY_UP
          @scroll_offset = [@scroll_offset - 1, 0].max
        when KEY_DOWN
          @scroll_offset += 1
        when KEY_RESIZE
          clear
        end
      end
    ensure
      close_screen
    end
  end

  private

  def fetch_data
    @data = []

    begin
      # Fetch cryptocurrencies
      currencies = Currencies.load(@config)
      crypto_values = {}

      @config.cryptos_list.each do |crypto|
        if currencies && currencies[crypto]
          crypto_values[crypto] = currencies[crypto]
          usd_value = currencies[crypto]['usd'].to_f
          @data << {
            type: :crypto,
            name: crypto.capitalize,
            value: usd_value,
            formatted_value: format_currency(usd_value),
            change: 0.0 # Could add 24h change if available
          }
        end
      end

      # Fetch currency pairs
      @config.currencies_list.each do |pair|
        from, to = pair.split('/')
        first_crypto = crypto_values.values.first
        if first_crypto && first_crypto[to] && first_crypto[from]
          rate = first_crypto[to].to_f / first_crypto[from].to_f
          @data << {
            type: :currency,
            name: "#{from.upcase}/#{to.upcase}",
            value: rate,
            formatted_value: rate.round(4).to_s,
            change: 0.0
          }
        end
      end

      # Fetch stocks
      # stocks = Stocks.load(@config)
      # stocks.each do |symbol, price|
      #   @data << {
      #     type: :stock,
      #     name: symbol.upcase,
      #     value: price.to_f,
      #     formatted_value: format_currency(price.to_f),
      #     change: 0.0 # Could add change if available
      #   }
      # end
    rescue => e
      @data << {
        type: :error,
        name: 'Error',
        value: 0,
        formatted_value: e.message[0..50],
        change: 0.0
      }
    end
  end

  def draw_ui
    clear

    # Get terminal dimensions
    max_y = lines
    max_x = cols

    # Draw header
    draw_header(max_x)

    # Draw data table
    draw_table(max_y, max_x)

    # Draw footer
    draw_footer(max_y, max_x)

    refresh
  end

  def draw_header(max_x)
    setpos(0, 0)
    attron(color_pair(1) | A_BOLD) do
      addstr(" " * max_x)
      setpos(0, (max_x - 30) / 2)
      addstr("STOCKS & CURRENCIES MONITOR")
    end

    setpos(1, 0)
    attron(color_pair(1)) do
      addstr(" " * max_x)
      setpos(1, 2)
      addstr("TYPE")
      setpos(1, 15)
      addstr("ASSET")
      setpos(1, 45)
      addstr("VALUE")
      setpos(1, 65)
      addstr("CHANGE")
    end

    setpos(2, 0)
    addstr("─" * max_x)
  end

  def draw_table(max_y, max_x)
    visible_rows = max_y - HEADER_HEIGHT - FOOTER_HEIGHT - 1
    start_idx = @scroll_offset
    end_idx = [@scroll_offset + visible_rows, @data.size].min

    row = HEADER_HEIGHT

    @data[start_idx...end_idx].each do |item|
      break if row >= max_y - FOOTER_HEIGHT - 1

      setpos(row, 0)

      # Choose color based on type and change
      color = case item[:type]
              when :crypto
                color_pair(2) # Green for crypto
              when :stock
                color_pair(6) # Magenta for stocks
              when :currency
                color_pair(3) # Yellow for currencies
              when :error
                color_pair(4) # Red for errors
              else
                color_pair(2)
              end

      attron(color) do
        # TYPE
        setpos(row, 2)
        type_str = item[:type].to_s.upcase[0..8]
        addstr(type_str.ljust(10))

        # ASSET
        setpos(row, 15)
        addstr(item[:name][0..28].ljust(29))

        # VALUE
        setpos(row, 45)
        addstr(item[:formatted_value].rjust(18))

        # CHANGE (placeholder for now)
        setpos(row, 65)
        change_str = item[:change] >= 0 ? "+#{item[:change]}%" : "#{item[:change]}%"
        addstr(change_str.rjust(10))
      end

      row += 1
    end

    # Fill remaining rows with empty space
    while row < max_y - FOOTER_HEIGHT - 1
      setpos(row, 0)
      addstr(" " * max_x)
      row += 1
    end
  end

  def draw_footer(max_y, max_x)
    setpos(max_y - 1, 0)
    attron(color_pair(5)) do
      footer_text = " Total: #{@data.size} assets | ↑↓: Scroll | R: Refresh | Q: Quit | Auto-refresh: #{REFRESH_INTERVAL}s "
      addstr(footer_text.ljust(max_x))
    end
  end

  def format_currency(value)
    if value >= 1_000_000
      "$#{(value / 1_000_000.0).round(2)}M"
    elsif value >= 1_000
      "$#{(value / 1_000.0).round(2)}K"
    else
      "$#{value.round(2)}"
    end
  end

  def number_with_delimiter(number)
    number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
end
