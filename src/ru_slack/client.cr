# encoding: utf-8

require "uri"
require "json"
require "http/client"
require "http/web_socket"
require "./exceptions.cr"

module RuSlack
  class Client
    @ws : HTTP::WebSocket?

    def initialize(token : String)
      @token = token
      @on_message_block = {} of String => Array(JSON::Any -> )
      @ws = nil
      @name = ""
      @connecting = Channel(Bool).new
      @pong_time = 0
    end

    def rtm_start
      loop do
        begin
          url = request_rtm_url
          @pong_time = Time.now.epoch
          @ws = ws = HTTP::WebSocket.new(URI.parse(url))
          ws.on_message(&-> receive_message(String))
          ws.on_close(&-> on_close(String))
          ping_sender
          ws.run
        rescue e : ReconnectException
          @connecting.close
          puts "disconnected: #{e.inspect}"
          sleep 5
          @connecting = Channel(Bool).new
          puts "retry"
        end
      end
    end

    def on(type : Symbol, &block : JSON::Any ->)
      @on_message_block[type.to_s] ||= [] of (JSON::Any ->)
      @on_message_block[type.to_s].push(block)
    end

    def post(channel : String, text : String)
      ws = @ws
      if ws.is_a?(HTTP::WebSocket)
        ws.send({
          id: Time.now.epoch,
          type: "message",
          channel: channel,
          text: text
        }.to_json)
      end
    end

    def request_rtm_url
      response = HTTP::Client.get("https://slack.com/api/rtm.start?token=#{@token}")
      json = JSON.parse(response.body)
      raise APIException.new(response.body) unless json["ok"]
      @name = json["self"]["name"].to_s
      puts json["url"].to_s
      json["url"].to_s
    end

    def receive_message(m : String)
      json = JSON.parse(m)
      puts json.inspect
      type = json["type"]?.to_s
      if json["reply_to"]?
        case type
        when "pong"
          @pong_time = json["reply_to"].to_s.to_i
        end
      else
        if json.size > 0
          if @on_message_block.has_key?(type)
            @on_message_block[type].each do |block|
              block.call(json)
            end
          else
            print "[missing] "
            puts type
          end
        end
      end
    end

    def on_close(m : String)
      raise ReconnectException.new("on_close")
    end

    def ping_sender
      spawn do
        loop do
          sleep 3
          break if @connecting.closed?
          if Time.now.epoch - @pong_time < 10
            ws = @ws
            if ws
              ws.send({
                id: Time.now.epoch,
                type: "ping"
              }.to_json)
            end
          else
            raise ReconnectException.new("not receive pong message")
          end
        end
      end
    end
  end
end

