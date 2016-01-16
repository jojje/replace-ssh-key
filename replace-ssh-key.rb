#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'net/ssh'
require 'yaml'
require 'digest/md5'

# Lookup cache to speed up repeated connection checks.
module Cache
  def cache(key, file='_replace_ssh_key.cache')
    entries = File.exists?(file) ? YAML.load(File.read(file)) : {}
    unless entries.has_key? key
      entries[key] ||= yield
      open(file,'w'){|f| f.print(YAML.dump(entries)) }
    end
    entries[key]
  end
end

class Proxy
  attr_reader :opts

  def initialize(opts=OpenStruct.new)
    @opts = opts
  end

  def can_connect?(host, key)
    @key_hash ||= Digest::MD5.hexdigest(File.read(key))
    timeout = opts.timeout || 5
    cmd = %|ssh -oBatchMode=yes -oConnectTimeout=#{timeout} -i "#{key}" "#{host}" exit|
    cache("#{host} #{@key_hash}") do
      STDERR.puts "Checking if able to connect to #{host} .."
      run(cmd)
    end
  end

  def replace_key(host, old_key, new_key)
    old_content = File.read("#{old_key}.pub").split[0..1].join(" ")
    new_content = File.read("#{new_key}.pub").strip
    srcfile = "~/.ssh/authorized_keys"
    tmpfile = "~/.ssh/authorized_keys.tmp"

    chained =<<-EOS.gsub(/^\s{6}/,"")
      grep -v "#{old_content}" #{srcfile} > #{tmpfile}
      echo "#{new_content}" >> #{tmpfile}
      chmod 600 #{tmpfile}
      mv #{tmpfile} #{srcfile}
    EOS

    chained = chained.split("\n").join(" && ").gsub('"','\"')

    cmd = %|ssh -i "#{old_key}" "#{host}" "#{chained}"|

    puts "Replacing key on: #{host}"

    run cmd, opts.verbose
  end

 private

  include Cache
  def run(cmd, show_output=false)
    puts cmd if opts.verbose
    unless opts.dry_run
      output = IO.popen("#{cmd} 2>&1") {|io| io.read }
      exitcode = $?.to_i
      puts output if show_output
      exitcode == 0
    else
      true
    end
  end
end

def assert_file(file, term="file")
  error "No #{term} provided" unless file
  file = File.expand_path(file)
  error "No such #{term}: #{file}" unless File.exists?(file)
  file
end

def assert_key(keyfile)
  assert_file(keyfile, "key")
end

def hosts
  file = assert_file( File.join(ENV['HOME'], "/.ssh/known_hosts") )
  File.read(file).split("\n").map{|line|
    host_field = line.split.first
    host_field.split(",").first.split(":").first.gsub(/[\[\]]/,'')
  }.sort.uniq
end

def list_servers
  puts hosts.sort
end

def connect_to_each_server(opts)
  key = assert_key(opts.old_key)
  proxy = Proxy.new(opts)

  STDERR.print "Validity by host of key: #{key}\n\n"
  hosts.each do |host|
    valid = proxy.can_connect?(host, key)
    puts "#{valid}  #{host}"
  end
end

def replace_on_each_server(opts)
  old_key, new_key = assert_key(opts.old_key), assert_key(opts.new_key)
  [old_key, new_key].each{|key| assert_key("#{key}.pub") }
  proxy = Proxy.new(opts)

  hosts.each do |host|
    next unless proxy.can_connect?(host, old_key)
    proxy.replace_key(host, old_key, new_key)
  end
end


############################################################################
# CLI handling
############################################################################

def error(msg) puts msg; exit 1 end

# properly line break long option descriptions
def wrap(str, maxwidth=42)
  str.split.reduce([[]]){|a,s|
    a << [] if (a.last+[s]).join(" ").size > maxwidth
    a.last << s; a
  }.map{|sa| sa.join(" ")}
end

def parse_args
  options = OpenStruct.new({:timeout => 5})
  parser = OptionParser.new do |opts|
    opts.banner = <<-EOS.gsub(/^\s{6}/,'')
      Usage: #{File.basename $0} [options] [OLD_KEY [NEW_KEY]]
      
      Swaps an old SSH key for a new one on all known and connectable hosts/servers
      where the OLD_KEY allows login. The user used for login will be either the
      current user or whatever user mapping results from the user's machine or per-
      user SSH client configuration (e.g. $HOME/.ssh/config)
      
      Arguments:
        OLD_KEY and NEW_KEY are both paths to the respective keys.
      
      Options:
    EOS
    opts.on('-l', '--list', *wrap('List the servers that are going to be tried.')) do |o|
      options.cmd = :list
    end
    opts.on('-c', '--connect', *wrap('Check which of the servers can be logged into using the old key.')) do |o|
      options.cmd = :connect
    end
    opts.on('-t', "--timeout=#{options.timeout}", *wrap('Treat the connection attempt as failed unless connection was established within these many seconds.')) do |o|
      options.timeout = o.to_i
    end
    opts.on('-R', '--replace', *wrap('Perform the actual key replacement action.')) do |o|
      options.cmd = :replace
    end
    opts.on('-v', '--verbose', *wrap('Show verbose output')) do |o|
      options.verbose = true
    end
    opts.on('-d', '--dry-run', *wrap('Simulate the key replacement process')) do |o|
      options.dry_run = true
    end
  end

  begin
    parser.parse!
  rescue => e
    puts e; exit 1
  end

  options.old_key = ARGV.shift
  options.new_key = ARGV.shift

  error parser.to_s unless options.cmd

  options
end

if __FILE__ == $0
  opts = parse_args
  case opts.cmd
  when :list
    list_servers
  when :connect
    connect_to_each_server(opts)
  when :replace
    replace_on_each_server(opts)
  else
    puts "invalid option, a bug: #{opts.cmd}"
  end
end
