require 'set'

module Proxy::DHCP
  class SubnetService
    include Proxy::Log

    attr_reader :m, :subnets, :subnet_keys, :leases_by_ip, :leases_by_mac, :reservations_by_ip, :reservations_by_mac, :reservations_by_name

    def initialize(leases_by_ip, leases_by_mac, reservations_by_ip, reservations_by_mac, reservations_by_name, subnets = {})
      @subnets = subnets
      @subnet_keys = Trie.new
      @leases_by_ip = leases_by_ip
      @leases_by_mac = leases_by_mac
      @reservations_by_ip = reservations_by_ip
      @reservations_by_mac = reservations_by_mac
      @reservations_by_name = reservations_by_name
      @m = Monitor.new
    end

    def self.initialized_instance
      new(::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new,
          ::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new)
    end

    def add_subnet(subnet)
      m.synchronize do
        key = ipv4_to_i(subnet.network) & ipv4_to_i(subnet.netmask)
        raise Proxy::DHCP::Error, "Unable to add subnet #{subnet}" if subnets.key?(key)
        logger.debug("Added a subnet: #{subnet.network}")
        subnets[key] = subnet
        subnet_keys.add(key)
        subnet
      end
    end

    def add_subnets(*subnets)
      m.synchronize do
        subnets.each { |s| add_subnet(s) }
        subnets
      end
    end

    def delete_subnet(subnet_address)
      m.synchronize { subnets.delete(ipv4_to_i(subnet_address)); subnet_keys.delete(ipv4_to_i(subnet_address)) }
      logger.debug("Deleted a subnet: #{subnet_address}")
    end

    def find_subnet(address)
      m.synchronize do
        ipv4_as_i = ipv4_to_i(address)
        return subnets[ipv4_as_i] if subnets.key?(ipv4_as_i)

        closest_subnet = subnet_keys.find_or_predecessor(ipv4_as_i)
        if closest_subnet
          closest_subnet = subnets[closest_subnet]
          closest_subnet if closest_subnet && closest_subnet.include?(address)
        end
      end
    end

    def do_find_subnet(a_slice, all_subnets, address_as_i, address)
      return nil if a_slice.empty?
      if a_slice.size == 1
        return all_subnets[a_slice.first].include?(address) ? all_subnets[a_slice.first] : nil
      end
      if a_slice.size == 2
        return all_subnets[a_slice.first] if all_subnets[a_slice.first].include?(address)
        return all_subnets[a_slice.last] if all_subnets[a_slice.last].include?(address)
        return nil
      end

      i = a_slice.size/2 - 1
      distance_left = address_as_i - a_slice[i]
      distance_right = address_as_i - a_slice[i+1]

      # a shortcut
      if distance_left > 0 && distance_right < 0
        return all_subnets[a_slice[i]].include?(address) ? all_subnets[a_slice[i]] : nil
      end

      return do_find_subnet(a_slice[0..i], all_subnets, address_as_i, address) if distance_left.abs < distance_right.abs
      do_find_subnet(a_slice[i+1..-1], all_subnets, address_as_i, address)
    end

    def ipv4_to_i(ipv4_address)
      ipv4_address.split('.').inject(0) { |i, octet| (i << 8) + (octet.to_i & 0xff) }
    end

    def all_subnets
      m.synchronize { subnets.values }
    end

    def add_lease(subnet_address, record)
      m.synchronize do
        leases_by_ip[subnet_address, record.ip] = record
        leases_by_mac[subnet_address, record.mac] = record
      end
      logger.debug("Added a lease record: #{record.ip}:#{record.mac}")
    end

    def add_host(subnet_address, record)
      m.synchronize do
        reservations_by_ip[subnet_address, record.ip] = record
        reservations_by_mac[subnet_address, record.mac] = record
        reservations_by_name[record.name] = record
      end
      logger.debug("Added a reservation: #{record.ip}:#{record.mac}:#{record.name}")
    end

    def delete_lease(record)
      m.synchronize do
        leases_by_ip.delete(record.subnet.network, record.ip)
        leases_by_mac.delete(record.subnet.network, record.mac)
      end
      logger.debug("Deleted a lease record: #{record.ip}:#{record.mac}")
    end

    def delete_host(record)
      m.synchronize do
        reservations_by_ip.delete(record.subnet.network, record.ip)
        reservations_by_mac.delete(record.subnet.network, record.mac)
        reservations_by_name.delete(record.name)
      end
      logger.debug("Deleted a reservation: #{record.ip}:#{record.mac}:#{record.name}")
    end

    def find_lease_by_mac(subnet_address, mac_address)
      m.synchronize { leases_by_mac[subnet_address, mac_address] }
    end

    def find_host_by_mac(subnet_address, mac_address)
      m.synchronize { reservations_by_mac[subnet_address, mac_address] }
    end

    def find_lease_by_ip(subnet_address, ip_address)
      m.synchronize { leases_by_ip[subnet_address, ip_address] }
    end

    def find_host_by_ip(subnet_address, ip_address)
      m.synchronize { reservations_by_ip[subnet_address, ip_address] }
    end

    def find_host_by_hostname(hostname)
      m.synchronize { reservations_by_name[hostname] }
    end

    def all_hosts(subnet_address = nil)
      if subnet_address
        return m.synchronize { reservations_by_ip[subnet_address] ? reservations_by_ip.values(subnet_address) : [] }
      end
      m.synchronize { reservations_by_ip.values }
    end

    def all_leases(subnet_address = nil)
      if subnet_address
        return m.synchronize { leases_by_ip[subnet_address] ? leases_by_ip.values(subnet_address) : [] }
      end
      m.synchronize { leases_by_ip.values }
    end

    def clear
      m.synchronize do
        subnets.clear
        leases_by_ip.clear
        leases_by_mac.clear
        reservations_by_ip.clear
        reservations_by_mac.clear
        reservations_by_name.clear
      end
    end

    def group_changes
      m.synchronize { yield }
    end

    class Trie
      attr_reader :root # MS bit

      def initialize
        @root = TrieEntry.new
      end

      def add(key)
        key_bits = to_bits(key)
        parent = find_parent(root, key_bits)
        last_bit = key_bits.first.zero? ? :zero= : :one=
        parent.send(last_bit, TrieEntry.new)
      end

      def find_or_predecessor(key)
        memo = []
        find_or_predecessor_internal(root, to_bits(key), memo)

        (0..3).inject(0) do |r, b|
          r = r << 8
          r += memo[b*8,8].join.to_i(2)
        end
      end

      private

      def find_parent(root, bits)
        return root if bits.length == 1

        next_bit = bits.shift
        next_entry = if next_bit.zero?
                       root.zero = TrieEntry.new if root.zero.nil?
                       root.zero
                     else
                       root.one = TrieEntry.new if root.one.nil?
                       root.one
                     end

        find_parent(next_entry, bits)
      end

      def find_or_predecessor_internal(root, bits, memo)
        return root if bits.empty? # success
        return nil if root.nil? # failed, caller should find predecessor

        next_bit = bits.shift

        result = if next_bit.zero? && root.zero
                   memo << 0
                   find_or_predecessor_internal(root.zero, bits, memo)
                 elsif next_bit == 1 && root.one
                   memo << 1
                   find_or_predecessor_internal(root.one, bits, memo)
                 end

        # find predecessor in left-hand tree if first searching the right
        if result.nil? && next_bit == 1 && root.zero
          memo << 0
          result = find_rightmost(root.zero, memo)
        end

        result
      end

      def find_rightmost(root, memo)
        if root.one
          memo << 1
          find_rightmost(root.one, memo)
        elsif root.zero
          memo << 0
          find_rightmost(root.zero, memo)
        elsif memo.length == 32 # leaf
          root
        else
          nil
        end
      end

      def to_bits(key)
        Array.new(32) { |i| key[i] }.reverse! # MS to LS
      end
    end

    class TrieEntry
      attr_accessor :zero, :one
    end
  end
end
