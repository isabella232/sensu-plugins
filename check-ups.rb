#!/usr/bin/env ruby

require 'sensu-plugin/check/cli'
require 'snmp'
require 'bigdecimal'

class CheckApcUps < Sensu::Plugin::Check::CLI
  OIDS = {
    output_status:     "1.3.6.1.4.1.318.1.1.1.4.1.1.0",
    capacity:          "1.3.6.1.4.1.318.1.1.1.2.2.1.0",
    current:           "1.3.6.1.4.1.318.1.1.1.4.2.4.0",
    frequency_in:      "1.3.6.1.4.1.318.1.1.1.3.2.4.0",
    frequency_out:     "1.3.6.1.4.1.318.1.1.1.4.2.2.0",
    last_test_result:  "1.3.6.1.4.1.318.1.1.1.7.2.3.0",
    load:              "1.3.6.1.4.1.318.1.1.1.4.2.3.0",
    runtime:           "1.3.6.1.4.1.318.1.1.1.2.2.3.0",
    battery_status:    "1.3.6.1.4.1.318.1.1.1.2.1.1.0",
    replace_battery:   "1.3.6.1.4.1.318.1.1.1.2.2.4.0",
    internal_temp:     "1.3.6.1.4.1.318.1.1.1.2.2.2.0",
    external_temp:     "1.3.6.1.4.1.318.1.1.25.1.2.1.6.2.1",
    voltage_in:        "1.3.6.1.4.1.318.1.1.1.3.2.1.0",
    voltage_out:       "1.3.6.1.4.1.318.1.1.1.4.2.1.0"
  }

  def self.add_numeric_check(name, default_expected_range, desc)
    self.option name,
        long: "--#{name} #{desc} (default #{default_expected_range})",
        default: default_expected_range.inspect

    (@@checks ||= []) << ->(snmp, config) do
      config_value = config[name]
      if (config[name] !~ /\.\./)
        config_value = "#{config_value}..#{config_value}"
      end
      range = Range.new(*config_value.split("..").map(&BigDecimal.method(:new)))
      value = BigDecimal.new(snmp.get(OIDS[name]).each_varbind.to_a[0].value.to_i)

      unless (range.include?(value))
        "expected #{name} of #{value} to be in the range #{range}"
      end
    end
  end

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

  add_numeric_check :output_status,    2,                     "output status"
  add_numeric_check :capacity,         95..100,                "% battery capacity"
  add_numeric_check :current,          1..15,                  "output current (amps)"
  add_numeric_check :frequency_in,     59.9..60.1,             "input frequency"
  add_numeric_check :frequency_out,    59.9..60.1,             "output frequency"
  add_numeric_check :last_test_result, 1,                      "last self test result"
  add_numeric_check :load,             10..60,                 "% load"
  add_numeric_check :runtime,          60000..Float::INFINITY, "runtime centiseconds"
  add_numeric_check :battery_status,   2,                      "battery status"
  add_numeric_check :replace_battery,  1,                      "battery replacement indicator"
  add_numeric_check :internal_temp,    20..35,                 "internal temperature (celsius)"
  add_numeric_check :external_temp,    20..27,                 "external temperature (celsius)"
  add_numeric_check :voltage_in,       119..121,               "input voltage (volts)"
  add_numeric_check :voltage_out,      119..120,               "output voltage (volts)"

  def run
    begin
      mgr = SNMP::Manager.new(
        host: config[:host],
        community: config[:community],
        version: config[:snmp_version].to_sym,
        timeout: config[:timeout].to_i
      )

      errors = @@checks.map { |check| check.call(mgr, config) }.compact
      critical errors * "\n" if (errors.any?)
      ok
    ensure
      mgr.close
    end
  end
end