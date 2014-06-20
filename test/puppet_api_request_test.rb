require 'test_helper'
require 'proxy/puppet'
require 'proxy/puppet/api_request'
require 'webmock/test_unit'

class PuppetApiRequestTest < Test::Unit::TestCase
  def setup
    Proxy::Puppet::Initializer.expects(:load)
    Puppet.expects(:[]).with(:certname).returns('puppet.example.com')
    Facter.stubs(:value).with(:fqdn).returns('puppet.example.com')
  end

  def stub_certs
    File.expects(:exist?).with('/var/lib/puppet/ssl/certs/ca.pem').returns(true)
    File.expects(:exist?).with('/var/lib/puppet/ssl/certs/puppet.example.com.pem').returns(true)
    File.expects(:exist?).with('/var/lib/puppet/ssl/private_keys/puppet.example.com.pem').returns(true)
  end

  def fixtures
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'authentication'))
  end

  def test_get_environments
    SETTINGS.stubs(:puppet_url).returns('http://localhost:8140')
    stub_certs
    stub_request(:get, 'http://localhost:8140/v2.0/environments').to_return(:body => '{"environments":{}}')
    result = Proxy::Puppet::EnvironmentsApi.new.find_environments
    assert_kind_of(Hash, result)
  end

  def test_ssl_config
    SETTINGS.stubs(:puppet_ssl_ca).returns(File.join(fixtures, 'puppet_ca.pem'))
    SETTINGS.stubs(:puppet_ssl_cert).returns(File.join(fixtures, 'foreman.example.com.cert'))
    SETTINGS.stubs(:puppet_ssl_key).returns(File.join(fixtures, 'foreman.example.com.key'))
    stub_request(:get, 'https://puppet.example.com:8140/v2.0/environments')
    Proxy::Puppet::EnvironmentsApi.new.find_environments
  end

  def test_api_error
    SETTINGS.stubs(:puppet_url).returns('http://puppet.example.com:8140')
    stub_certs
    stub_request(:get, 'http://puppet.example.com:8140/v2.0/environments').to_return(:status => 403, :body => 'Not allowed')
    assert_raise Proxy::Puppet::ApiError do
      Proxy::Puppet::EnvironmentsApi.new.find_environments
    end
  end
end
