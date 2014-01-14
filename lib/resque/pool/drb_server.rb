require 'drb/drb'

$SAFE = 1

class DrbServer
  include Singleton

  def start
    unless @service
      @service = DRb.start_service 'druby://localhost:9001', Resque::Pool.instance
      DRb.thread.join
    end
  end
end
