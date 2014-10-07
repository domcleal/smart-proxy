require 'proxy'

require 'fileutils'
require 'webrick/https'
require 'daemon' # FIXME: Do we still need this?

require 'checks'
require 'proxy/log'
require 'proxy/util'
require 'proxy/http_downloads'
require 'proxy/helpers'
require 'proxy/plugin'
require 'proxy/error'

require 'sinatra/base'
require 'rack-patch' if Rack.release < "1.3"
require 'sinatra-patch'
require 'sinatra/ssl_client_verification'
require 'sinatra/trusted_hosts'

::Sinatra::Base.register ::Sinatra::SSLClientVerification
::Sinatra::Base.register ::Sinatra::TrustedHosts

module Proxy
  class Launcher
    include ::Proxy::Log

    def pid_path
      SETTINGS.daemon_pid
    end

    def create_pid_dir
      if SETTINGS.daemon
        FileUtils.mkdir_p(File.dirname(pid_path)) unless File.exists?(pid_path)
      end
    end

    def https_enabled?
      SETTINGS.ssl_private_key and SETTINGS.ssl_certificate and SETTINGS.ssl_ca_file
    end

    def http_app
      return nil if SETTINGS.http_port.nil?
      app = Rack::Builder.new do
        ::Proxy::Plugins.enabled_plugins.each {|p| instance_eval(p.http_rackup)}
      end

      Rack::Server.new(
        :app => app,
        :server => :webrick,
        :Port => SETTINGS.http_port,
        :daemonize => false,
        :pid => (SETTINGS.daemon && !https_enabled?) ? pid_path : nil)
    end

    def https_app
      unless https_enabled?
        logger.warn "Missing SSL setup, https is disabled."
        nil
      else
        begin
          app = Rack::Builder.new do
            ::Proxy::Plugins.enabled_plugins.each {|p| instance_eval(p.https_rackup)}
          end

          Rack::Server.new(
            :app => app,
            :server => :webrick,
            :Port => SETTINGS.https_port,
            :SSLEnable => true,
            :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER,
            :SSLPrivateKey => OpenSSL::PKey::RSA.new(File.read(SETTINGS.ssl_private_key)),
            :SSLCertificate => OpenSSL::X509::Certificate.new(File.read(SETTINGS.ssl_certificate)),
            :SSLCACertificateFile => SETTINGS.ssl_ca_file,
            :daemonize => false,
            :pid => SETTINGS.daemon ? pid_path : nil)
        rescue => e
          logger.error "Unable to access the SSL keys. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
          nil
        end
      end
    end

    def launch
      ::Proxy::Plugins.configure_loaded_plugins

      create_pid_dir
      http_app = http_app()
      https_app = https_app()

      if http_app.nil? && https_app.nil?
        logger.error("Both http and https are disabled, unable to start.")
        exit(1)
      end

      Process.daemon if SETTINGS.daemon

      t1 = Thread.new { https_app.start } unless https_app.nil?
      t2 = Thread.new { http_app.start } unless http_app.nil?

      sleep 5 # Rack installs its own trap; Sleeping for 5 secs insures we overwrite it with our own
      trap(:INT) do
        exit(0)
      end

      (t1 || t2).join
    end
  end
end
