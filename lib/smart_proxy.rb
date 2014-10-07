APP_ROOT = "#{File.dirname(__FILE__)}/.."

require 'proxy'
require 'checks'
require 'proxy/log'
require 'proxy/settings'
require 'proxy/settings/plugin'
require 'proxy/settings/global'
require 'proxy/util'

require 'bundler_helper'
Proxy::BundlerHelper.require_groups(:default)

require 'proxy/launcher'

module Proxy
  SETTINGS = Settings.load_global_settings
  VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).chomp

  ::Sinatra::Base.set :run, false
  ::Sinatra::Base.set :root, APP_ROOT
  ::Sinatra::Base.set :views, APP_ROOT + '/views'
  ::Sinatra::Base.set :public_folder, APP_ROOT + '/public'
  ::Sinatra::Base.set :logging, false # we are not going to use Rack::Logger
  ::Sinatra::Base.use ::Proxy::LoggerMiddleware # instead, we have our own logging middleware
  ::Sinatra::Base.use ::Rack::CommonLogger, ::Proxy::Log.logger
  ::Sinatra::Base.set :env, :production

  require 'root/root'
  require 'facts/facts'
  require 'dns/dns'
  require 'tftp/tftp'
  require 'dhcp/dhcp'
  require 'puppetca/puppetca'
  require 'puppet_proxy/puppet'
  require 'bmc/bmc'
  require 'chef_proxy/chef'
  require "realm/realm"

  def self.version
    {:version => VERSION}
  end
end
