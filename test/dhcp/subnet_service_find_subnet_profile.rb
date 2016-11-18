require 'test_helper'
require 'ruby-prof'

require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'dhcp_common/subnet_service'

host_count = 200

[5000].each do |subnet_count|
  hosts = []
  s1 = s2 = 0
  subnets = (1..subnet_count).map do |i|
    s2 += 1
    if s2 % 256 == 0
      s1 += 1
      s2 = 0
    end

    prefix = "#{s1}.#{s2}.0"
    netmask = '255.255.255.0'
    host_count.times { |i| hosts << "#{prefix}.#{i}" }
    Proxy::DHCP::Subnet.new(prefix + '.0', netmask, {})
  end

  service = Proxy::DHCP::SubnetService.initialized_instance
  RubyProf.start
  subnets.each { |s| service.add_subnet(s) }
  hosts.each { |s| service.find_subnet(s) }

  result = RubyProf.stop
  printer = RubyProf::CallTreePrinter.new(result)
  printer.print
end
