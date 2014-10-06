require 'test_helper'
require 'json'
require 'sinatra/base'

ENV['RACK_ENV'] = 'test'

class SSLClientVerificationTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    TestApp.new
  end

  def test_http
    get '/test'
    assert last_response.ok?
  end

  def test_https_no_cert
    get '/test', {}, {'HTTPS' => 'on'}
    assert last_response.forbidden?
  end

  def test_https_cert
    get '/test', {}, {'HTTPS' => 'on', 'SSL_CLIENT_CERT' => '...'}
    assert last_response.ok?
  end

  private

  class TestApp < ::Sinatra::Base
    require_ssl_client_verification

    get '/test' do
      'success'
    end
  end
end
