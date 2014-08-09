module Proxy::Dns
  class Api < ::Sinatra::Base
    helpers ::Proxy::Helpers

    def dns_setup(opts)
      raise "Smart Proxy is not configured to support DNS" unless Proxy::Dns::Plugin.settings.enabled
      server_class = Proxy::Dns::Plugin.get_provider(Proxy::Dns::Plugin.settings.dns_provider)
      log_halt 400, "Unrecognized or missing DNS provider: #{Proxy::Dns::Plugin.settings.dns_provider || "MISSING"}" unless server_class
      @server = server_class.new(Proxy::SETTINGS, Proxy::Dns::Plugin.settings, opts)
    rescue => e
      log_halt 400, e
    end

    post "/?" do
      fqdn  = params[:fqdn]
      value = params[:value]
      type  = params[:type]
      begin
        dns_setup({:fqdn => fqdn, :value => value, :type => type})
        @server.create
      rescue Proxy::Dns::Collision => e
        log_halt 409, e
      rescue Exception => e
        log_halt 400, e
      end
    end

    delete "/:value" do
      case params[:value]
      when /\.(in-addr|ip6)\.arpa$/
        type = "PTR"
        value = params[:value]
      else
        fqdn = params[:value]
      end
      begin
        dns_setup({:fqdn => fqdn, :value => value, :type => type})
        @server.remove
      rescue => e
        log_halt 400, e
      end
    end
  end
end
