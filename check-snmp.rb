#!/usr/bin/env ruby
# Check SNMP
# ===
#
# This is a simple SNMP check script for Sensu, We need to supply details like
# Server, port, SNMP community, and Limits
#
#
# Requires SNMP gem
#
# USAGE:
#
#   check-snmp -h host -C community -O oid -w warning -c critical
#   check-snmp -h host -C community -O oid -m "(P|p)attern to match\.?"
#
#
#  Author Deepak Mohan Das   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'snmp'
require 'bigdecimal'

class CheckSNMP < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h host',
         default: '127.0.0.1'

  option :community,
         short: '-C snmp community',
         default: 'public'

  option :objectid,
         short: '-O OID',
         default: '1.3.6.1.4.1.2021.10.1.3.1'

  option :warning,
         short: '-w warning',
         default: '10'

  option :critical,
         short: '-c critical',
         default: '20'

  option :match,
         short: '-m match',
         description: 'Regex pattern to match against returned value'

  option :snmp_version,
         short: '-v version',
         description: 'SNMP version to use (SNMPv1, SNMPv2c (default))',
         default: 'SNMPv2c'

  option :comparison,
         short: '-o comparison operator',
         description: "Operator used to compare data with. Can be set to #{OPERATORS.inspect}",
         default: '>=',
         proc: ->(comparison) { (OPERATORS & [ comparison ]).first or raise "Invalid comparison: #{comparison}" }

  option :timeout,
         short: '-t timeout (seconds)',
         default: '1'

  OPERATORS = %w(< <= > >= ==)

  def run
    begin
      manager = SNMP::Manager.new(host: "#{config[:host]}",
                                  community: "#{config[:community]}",
                                  version: config[:snmp_version].to_sym,
                                  timeout: config[:timeout].to_i)
      response = manager.get(["#{config[:objectid]}"])

      response.each_varbind do |vb|
        if config[:match]
          if vb.value.to_s =~ /#{config[:match]}/
            ok
          else
            critical "Value: #{vb.value} failed to match Pattern: #{config[:match]}"
          end
        else
          comparison = config[:comparison]
          warning_threshold = BigDecimal.new(config[:warning].to_s)
          critical_threshold = BigDecimal.new(config[:critical].to_s)
          value = BigDecimal.new(vb.value.to_s)

          if value.send(comparison, critical_threshold)
            critical "Critical state detected: #{vb.value} #{comparison} #{critical_threshold}"
          elsif value.send(comparison, warning_threshold)
            warning "Warning state detected: #{vb.value} #{comparison} #{warning_threshold}"
          else
            ok vb.value.to_s
          end
        end
      end
    rescue SNMP::RequestTimeout
      unknown "#{config[:host]} not responding"
    rescue => e
      unknown "An unknown error occured: #{e.inspect}"
    ensure
      manager.close if (manager)
    end
  end
end