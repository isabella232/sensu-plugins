#!/usr/bin/env ruby

require 'sensu-plugin/check/cli'
require 'snmp'
require 'bigdecimal'

class CheckApcUps < Sensu::Plugin::Check::CLI
  NumericCheck = Struct.new(:name, :default_expected_value, :oid) do
    def check(snmp, config)
      expected_value = config[name]
      value = BigDecimal.new(snmp.get(oid).each_varbind.to_a[0].value.to_i)
      expected_value.include?("..") ?
          check_range(expected_value, value) :
          check_value(expected_value, value)
    end

    def check_value(expected_value, value)
      expected_value = BigDecimal.new(expected_value)
      expected_value == value ?
          [ "#{name} of #{value.to_s("F")} is OK", nil ] :
          [ nil, "expected #{name} of #{value.to_s("F")} to be #{expected_value.to_s("F")}" ]
    end

    def check_range(expected_value, value)
      min, max = expected_value.split("..").map(&BigDecimal.method(:new))
      Range.new(min, max).include?(value) ?
          [ "#{name} of #{value.to_s("F")} is OK", nil ] :
          [ nil, "expected #{name} of #{value.to_s("F")} to be in [#{min.to_s("F")}, #{max.to_s("F")}]" ]
    end

    def cmd_options
      [ name, long: "--#{name} (default #{default_expected_value})", default: default_expected_value.inspect ]
    end
  end

  CHECKS = [
    NumericCheck.new(:output_status,    2,                      "1.3.6.1.4.1.318.1.1.1.4.1.1.0"),
    NumericCheck.new(:capacity,         95..100,                "1.3.6.1.4.1.318.1.1.1.2.2.1.0"),
    NumericCheck.new(:current,          1..15,                  "1.3.6.1.4.1.318.1.1.1.4.2.4.0"),
    NumericCheck.new(:frequency_in,     58..62,                 "1.3.6.1.4.1.318.1.1.1.3.2.4.0"),
    NumericCheck.new(:frequency_out,    58..62,                 "1.3.6.1.4.1.318.1.1.1.4.2.2.0"),
    NumericCheck.new(:last_test_result, 1,                      "1.3.6.1.4.1.318.1.1.1.7.2.3.0"),
    NumericCheck.new(:load,             10..60,                 "1.3.6.1.4.1.318.1.1.1.4.2.3.0"),
    NumericCheck.new(:runtime,          60000..Float::INFINITY, "1.3.6.1.4.1.318.1.1.1.2.2.3.0"),
    NumericCheck.new(:battery_status,   2,                      "1.3.6.1.4.1.318.1.1.1.2.1.1.0"),
    NumericCheck.new(:replace_battery,  1,                      "1.3.6.1.4.1.318.1.1.1.2.2.4.0"),
    NumericCheck.new(:internal_temp,    20..35,                 "1.3.6.1.4.1.318.1.1.1.2.2.2.0"),
    NumericCheck.new(:external_temp,    20..30,                 "1.3.6.1.4.1.318.1.1.25.1.2.1.6.2.1"),
    NumericCheck.new(:voltage_in,       119..121,               "1.3.6.1.4.1.318.1.1.1.3.2.1.0"),
    NumericCheck.new(:voltage_out,      119..120,               "1.3.6.1.4.1.318.1.1.1.4.2.1.0"),
  ]

  option :host,
         short: '-h host',
         required: true

  option :community,
         short: '-C snmp_community',
         default: 'public'

  option :snmp_version,
         short: '-v version',
         description: 'SNMP version',
         default: 'SNMPv2c'

  option :timeout,
         short: '-t timeout (seconds)',
         default: '1'

  CHECKS.map { |check| option(*check.cmd_options) }

  def run
    begin
      snmp = SNMP::Manager.new(
        host: config[:host],
        community: config[:community],
        version: config[:snmp_version].to_sym,
        timeout: config[:timeout].to_i
      )

      ok, critical = CHECKS.map { |check| check.check(snmp, config) }.transpose.map(&:compact)
      self.critical(critical * "\n") if (critical.any?)
      self.ok(ok * "\n")
    ensure
      snmp.close
    end
  end
end