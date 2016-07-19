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
    end

    def rtm_start
      loop do
        begin
          url = request_rtm_url
          @ws = ws = HTTP::WebSocket.new(URI.parse(url))

          ws.on_message do |m|
            json = JSON.parse(m)
            puts json.inspect
            type = json["type"]?.to_s
            if json["reply_to"]?
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

          ws.on_close do |m|
            puts "しんだ"
            puts m.inspect
            raise ReconnectException.new("on_close")
          end

          spawn do
            loop do
              ws.send({
                id: Time.now.epoch,
                type: "ping"
              }.to_json)
              sleep 5
            end
          end

          ws.run
        rescue e : ReconnectException
          puts "happen recconect"
          sleep 5
          next
        end

        # happen unknown error :(
        break
      end
    end

    def on_message(type : Symbol, &block : JSON::Any ->)
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
      unless json["ok"]
        puts json.inspect
        raise "Slack API げきおこ"
      end
      puts json["self"]["name"].inspect
      puts json["url"].inspect
      json["url"].to_s
    end
  end
end

