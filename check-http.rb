#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'

class CheckAppHealth < Sensu::Plugin::Check::CLI
  option :uri,
    :short => '-u URI',
    :description => 'URI'

  option :username,
    :short => "-U BASIC_AUTH_USER",
    :description => 'Basic auth username'

  option :password,
    :short => "-p BASIC_AUTH_PASSWORD",
    :description => 'Basic auth password'

  option :timeout,
    :short => '-t SECS',
    :proc => :to_i.to_proc,
    :description => 'Timeout'

  def run
    timeout(config[:timeout]) do
      uri = URI(config[:uri])
      response = Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri
        if (config[:username])
          request.basic_auth(config[:username], config[:password])
        end
        response = http.request(request)
      end

      if (response.is_a?(Net::HTTPSuccess))
        ok(response.body)
      else
        msg = "received #{response.code} http response"
        msg << ":\n#{response.body}" unless (response.body.empty?)
        critical(msg)
      end
    end
  rescue
    critical([ $!.message, *$!.backtrace ] * "\n")
  end
end
