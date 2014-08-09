require 'dns/dns_plugin'

module Proxy::Dns
  class Error < RuntimeError; end
  class Collision < RuntimeError; end
  class Record
    include Proxy::Log

    def initialize settings, module_settings, options={}
      @server = module_settings.dns_server || "localhost"
      @fqdn   = options[:fqdn]
      @ttl    = module_settings.dns_ttl || options[:ttl] || "86400"
      @type   = options[:type] || "A"
      @value  = options[:value]

      raise("Must define FQDN or value") if @fqdn.nil? and @value.nil?
    end
  end
end
