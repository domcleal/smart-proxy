if RUBY_VERSION < "1.9"
  require 'fileutils'

  module Process
    def self.daemon(nochdir = nil, noclose = nil)
      exit if fork                     # Parent exits, child continues.
      Process.setsid                   # Become session leader.
      exit if fork                     # Zap session leader. See [1].

      unless nochdir
        Dir.chdir "/"                  # Release old working directory.
      end

      File.umask 0022                  # Ensure sensible umask. Adjust as needed.

      logdir = File.join(APP_ROOT, "logs")
      FileUtils.mkdir_p logdir
      log = logdir +"/access.log"
      unless noclose
        STDIN.reopen "/dev/null"       # Free file descriptors and
        STDOUT.reopen log, "a" # point them somewhere sensible.
        STDERR.reopen "/dev/null"
        STDOUT.sync = true
      end

      trap("TERM") { exit }

      return 0
    end
  end
end
