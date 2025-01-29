require 'sinatra/base'
require 'json'

class Ui
  def initialize(app)
    @app = app
  end

  def stream(&block)
    @app.stream(:keep_open) do |out|
      block.call(Updater.new(out))
    rescue StandardError
      out.close
      raise
    end
  end

  def fragment(html, modifiers = {})
    stream do |out|
      out.fragment(html, modifiers)
      out.close
    end
  end

  class Updater
    def initialize(out)
      @out = out
    end

    def close = @out.close

    def fragment(html, modifiers = {})
      data = ["fragments #{html}"]
      data = modifiers.each.with_object(data) do |(k, v), acc|
        acc << "#{k} #{v}"
      end

      data_str = data.map { |d| "data: #{d}" }.join("\n")
      @out << %(event: datastar-merge-fragments\n#{data_str}\n\n)
    end

    def signals(data)
      @out << %(event: datastar-merge-signals\ndata: signals #{JSON.dump(data)}\n\n)
    end
  end
end

class App < Sinatra::Base
  @@running = true

  @@list = false

  def self.running?
    @@running
  end

  def self.signal_stop!
    @@running = false
  end

  helpers do
    def ui
      @ui ||= Ui.new(self)
    end
  end

  get '/' do
    erb :index
  end

  post '/toggle', provides: 'text/event-stream' do
    @@list = !@@list
    label = @@list ? 'List mode: ON' : 'List mode: OFF'
    ui.fragment %(<button id="toggle" data-on-click="@post('/toggle')">#{label}</button>)
  end

  get '/stream', provides: 'text/event-stream' do
    ui.stream do |out|
      out.fragment %(<button id="start" disabled>Running</button>)

      count = 1
      while true
        sleep 0.05
        # Update this HTML fragment on the page
        if @@list
          # Or pass Data* modifiers
          out.fragment %(<div>Time is: #{Time.now}</div>), selector: '#list', mergeMode: 'append'
        else
          out.fragment %(<div id="time">Time is: #{Time.now}</div>)
        end

        # Update the signals on the page
        out.signals count: count
        count += 1
      end
    end
  end


end

trap('INT') do
  puts('Closing!')
  App.signal_stop!
  puts('Byebye!')
  sleep 2
  exit
end
