require 'resolv'

module Sinatra
  module SSLClientVerification
    def require_ssl_client_verification
      helpers ::Proxy::Helpers
      helpers ::Proxy::Log

      before do
        if request.env['HTTPS'].to_s == 'on'
          if request.env['SSL_CLIENT_CERT'].to_s.empty?
            log_halt 403, "No client SSL certificate supplied"
          end
        else
          logger.debug("#{__method__}: skipping, non-HTTPS request")
        end
      end
    end
  end
end
