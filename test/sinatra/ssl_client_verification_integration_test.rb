require 'test_helper'
require 'sinatra/base'
require 'proxy/launcher'

ENV['RACK_ENV'] = 'test'

class SSLClientVerificationIntegrationTest < Test::Unit::TestCase
  def setup
    @t = Thread.new { Proxy::Launcher.new.https_app.start }
  end

  def teardown
    Thread.kill(@t)
    @t.join
  end

  def test_http
  end

  def test_https_no_cert
  end

  def test_https_cert
  end
end
