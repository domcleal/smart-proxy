module Proxy::Dns
  class Plugin < ::Proxy::Plugin
    extend ::Proxy::ProviderManager

    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :dns_provider => 'nsupdate'
    plugin :dns, ::Proxy::VERSION

    register_provider 'dnscmd', 'dns/providers/dnscmd', 'Proxy::Dns::Dnscmd'
    register_provider 'nsupdate', 'dns/providers/nsupdate', 'Proxy::Dns::Nsupdate'
    register_provider 'nsupdate_gss', 'dns/providers/nsupdate_gss', 'Proxy::Dns::NsupdateGSS'
    register_provider 'virsh', 'dns/providers/virsh', 'Proxy::Dns::Virsh'
  end
end
