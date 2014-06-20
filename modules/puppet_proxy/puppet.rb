require 'puppet_proxy/puppet_plugin'
module Proxy::Puppet
  class ApiError < ::StandardError; end
  class ConfigurationError < ::StandardError; end
  class DataError < ::StandardError; end
end
