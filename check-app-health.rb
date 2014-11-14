#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'

class CheckAppHealth < Sensu::Plugin::Check::CLI
  option :url,
    :short => '-u URL',
    :description => 'KernelWeb health check URL'

  option :timeout,
    :short => '-t SECS',
    :proc => :to_i.to_proc,
    :description => 'Timeout'

  def run
    timeout(config[:timeout]) do
      response = Net::HTTP.get_response(URI(config[:url]))
      if (Net::HTTPSuccess === response)
        ok(response.body)
      else
        critical(response.body)
      end
    end
  rescue
    critical($!.message)
  end
end
