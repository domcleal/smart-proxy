module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util
  require 'proxy/puppet/puppet_class'
  require 'proxy/puppet/environment'


  class << self
    def run *hosts
      # Search in /opt/ for puppet enterprise users
      default_path = ["/usr/sbin", "/usr/bin", "/opt/puppet/bin"]
      # search for puppet for users using puppet 2.6+
      puppetrun    = which("puppetrun", default_path) || which("puppet", default_path)
      sudo         = which("sudo", "/usr/bin")

      unless puppetrun and sudo
        logger.warn "sudo or puppetrun binary was not found - aborting"
        return false
      end

      # Append kick to the puppet command if we are not using the old puppetca command
      puppetrun << " kick" unless puppetrun.include?('puppetrun')
      sudo_puppetrun = "#{sudo} #{puppetrun}"

      puppet_cmd = [sudo_puppetrun, hosts.map {|h| ["--host", h]}].flatten

      # Returns a boolean with whether or not the command executed successfully.
      command = system(*puppet_cmd)

      if command
        return true
      else
        logger.warn command
        return false
      end
    end
  end
end
