require 'rb-inotify'

module ::Proxy::DHCP::ISC
  class InotifyLeasesFileObserver
    include ::Proxy::Log

    attr_reader :observer, :leases_filename

    def initialize(state_changes_observer, leases_path)
      @observer = state_changes_observer
      @leases_filename = File.expand_path(leases_path)
    end

    def monitor_leases
      @notifier = INotify::Notifier.new

      modify_callback = lambda do |event|
        logger.debug "caught :modify event on #{event.absolute_name}"
        observer.leases_modified
      end
      modify_watcher = @notifier.watch(leases_filename, :modify, &modify_callback)

      @notifier.watch(File.dirname(leases_filename), :moved_to) do |event|
        if event.absolute_name == leases_filename
          logger.debug "caught :moved_to event on #{event.absolute_name}"

          # re-register modify watch as the file has changed
          modify_watcher.close rescue nil
          modify_watcher = @notifier.watch(leases_filename, :modify, &modify_callback)

          observer.leases_recreated
        end
      end

      @notifier.run
    rescue INotify::QueueOverflowError => e
      logger.warn "Queue overflow occured when monitoring #{leases_filename}, restarting monitoring", e
      observer.leases_recreated
      retry
    rescue Exception => e
      logger.error "Error occured when monitoring #{leases_filename}", e
    end

    def start
      observer.monitor_started
      Thread.new { monitor_leases }
    end

    def stop
      @notifier.stop unless @notifier.nil?
      observer.monitor_stopped
    end
  end
end
