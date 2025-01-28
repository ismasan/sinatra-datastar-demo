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

  class Updater
    def initialize(out)
      @out = out
    end

    def fragment(html)
      @out << %(event: datastar-merge-fragments\ndata: fragments #{html}\n\n)
    end

    def signals(data)
      @out << %(event: datastar-merge-signals\ndata: signals #{JSON.dump(data)}\n\n)
    end
  end
end

class App < Sinatra::Base
  @@running = true

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

  get '/stream', provides: 'text/event-stream' do
    ui.stream do |out|
      while true
        sleep 1
        out.fragment %(<div id="time">Time is: #{Time.now}</div>)
        out.signals input: Time.now
        # out << %(event: datastar-merge-fragments\ndata: fragments <div id="time">#{Time.now}</div>\n\n)
        # out << %(event: datastar-merge-signals\ndata: signals {input:"#{Time.now}"}\n\n)
      end
    end

    # stream do |out|
    #   while true
    #     sleep 1
    #     out << %(event: datastar-merge-fragments\ndata: fragments <div id="time">#{Time.now}</div>\n\n)
    #     out << %(event: datastar-merge-signals\ndata: signals {input:"#{Time.now}"}\n\n)
    #   end
    #
    #   out << %(event: datastar-execute-script\ndata: script console.log("Shutting server down")\n\n)
    # rescue StandardError
    #   out.close
    #   raise
    # end
  end
end

trap('INT') do
  puts('Closing!')
  App.signal_stop!
  puts('Byebye!')
  sleep 2
  exit
end
