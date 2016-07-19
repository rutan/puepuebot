# encoding: utf-8

require "uri"
require "json"
require "http/client"
require "http/params"
require "./exceptions.cr"
require "./rtm_connector.cr"

module RuSlack
  class Client
    SLACK_API_BASE = "https://slack.com/api"

    def initialize(token : String)
      @token = token
    end

    getter :token

    def rtm
      @rtm ||= RTMConnector.new(self)
    end

    def users_list
      request_get("/users.list")
    end

    macro define_request_methods(types)
      {% for name in types %}
        def request_{{name}}(path : String, params : Hash | Nil = nil )
          if params.is_a?(Nil)
            params = {} of String => String | Int32 | Nil
          end
          params["token"] = @token.to_s
          url = "#{SLACK_API_BASE}#{path}"
          {% if name.id == "get" %}
            http_params = HTTP::Params.build do |builder|
              params.each do |key, value|
                builder.add key, value.to_s
              end
            end
            url += "?#{http_params.to_s}"
            puts url.inspect
            response = HTTP::Client.{{name}}(url)
          {% elsif name.id == "post" %}
            response = HTTP::Client.{{name}}_form(url, params)
          {% end %}
          JSON.parse(response.body)
        end
      {% end %}
    end

    define_request_methods([get, post])
  end
end

