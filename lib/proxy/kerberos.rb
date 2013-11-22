require 'rkerberos'

module Proxy::Kerberos
  def init_krb5_ccache keytab, principal
    begin
      krb5 = Kerberos::Krb5.new
      ccache = Kerberos::Krb5::CredentialsCache.new
    rescue => e
      logger.error "Failed to create kerberos objects: #{e}"
      raise "Failed to create kerberos objections: #{e}" 
   end
  
    logger.info "Requesting credentials for Kerberos principal #{principal} using keytab #{keytab}"
    begin
      krb5.get_init_creds_keytab principal, keytab, nil, ccache
    rescue => e
      logger.error "Failed to initialise credential cache from keytab: #{e}"
      raise "Failed to initailize credentials cache from keytab: #{e}"
    end
    logger.debug "Kerberos credential cache initialised with principal: #{ccache.primary_principal}"
  end
end
