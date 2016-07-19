# encoding: utf-8

require "uri"
require "json"
require "http/client"
require "./exceptions.cr"
require "./rtm_connector.cr"

module RuSlack
  class Client
    def initialize(token : String)
      @token = token
    end

    getter :token

    def rtm
      @rtm ||= RTMConnector.new(self)
    end
  end
end

