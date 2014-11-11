#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'open3'
require 'csv'

class CheckMysqlReplicationStatus < Sensu::Plugin::Check::CLI
  option :mysql_config,
    :short => '-C mysl_config_file',
    :description => 'mysql config file'

  option :warn,
    :short => '-w warn_lag_threshold',
    :description => 'Warning threshold for replication lag',
    :default => 120,
    :proc => :to_i.to_proc

  option :crit,
    :short => '-c critical_lag_threshold',
    :description => 'Critical threshold for replication lag',
    :default => 300,
    :proc => :to_i.to_proc

  option :help,
    :short => "-h",
    :long => "--help",
    :description => "Check MySQL replication status",
    :on => :tail,
    :boolean => true,
    :show_options => true,
    :exit => 0


  def run
    stdout, stderr, status = Open3.capture3(
      'mysql', "--defaults-extra-file=#{config[:mysql_config]}", '-B', '-e', 'show slave status'
    )

    if (!status.success? || stderr.length != 0)
      critical(stderr)
    end

    csv = CSV.parse(stdout, :col_sep => "\t", :headers => true)
    if (csv.size != 1)
      critical("unexpected results from sql query")
    end

    row = csv.first
    behind = begin
      Integer(row["Seconds_Behind_Master"])
    rescue
      critical("unexpected value for Seconds_Behind_Master: #{row["Seconds_Behind_Master"].inspect}")
    end

    critical("Slave SQL is not running")                     if (row["Slave_SQL_Running"] != "Yes")
    critical("Slave IO is not running")                      if (row["Slave_IO_Running"] != "Yes")
    critical("slave is #{behind} seconds behind the master") if (behind > config[:crit])
    warning("slave is #{behind} seconds behind the master")  if (behind > config[:warn])

    exit(0)
  end
end
