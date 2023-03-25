module Syn
  module Lock
    # Acquires the lock. The execution of the current fiber is suspended until
    # the lock is acquired.
    abstract def lock : Nil

    # Releases the lock.
    abstract def unlock : Nil

    # Acquires the lock, yields, then releases the lock, even if the block
    # raised an exception.
    def synchronize(& : -> U) : U forall U
      lock
      yield
    ensure
      unlock
    end

    # Releases the lock, suspends the current Fiber, then acquires the lock
    # again when the fiber is resumed.
    #
    # The Fiber must be enqueued manually.
    def suspend : Nil
      unlock
      ::sleep
      lock
    end

    # Identical to `#suspend` but if the fiber isn't manually resumed after
    # timeout is reached, then the fiber will be resumed automatically (and the
    # lock reacquired).
    #
    # Returns `true` if the timeout was reached, `false` otherwise.
    def suspend(timeout : Time::Span) : Bool
      unlock
      reached_timeout = Syn.sleep(timeout)
      lock
      reached_timeout
    end
  end
end
