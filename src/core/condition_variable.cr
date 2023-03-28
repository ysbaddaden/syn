require "./spin_lock"
require "./mutex"
require "./wait_list"

module Syn::Core
  # Synchronize execution of concurrently running fibers.
  #
  # This can be used to replace polling with a waiting list that can be resumed
  # when resources are available, while still behaving inside a mutually
  # exclusive context: when a waiting fiber is resumed, the mutex will be
  # locked.
  struct ConditionVariable
    def initialize
      @spin = SpinLock.new
      @waiting = WaitList.new
    end

    # Suspends the current fiber. The mutex is unlocked before the fiber is
    # suspended (the current fiber must be holding the lock) and will be locked
    # again after the fiber is resumed and before the function returns.
    def wait(mutex : Pointer(Mutex)) : Nil
      current = Fiber.current
      @spin.synchronize { @waiting.push(current) }
      mutex.value.unlock
      ::sleep
      mutex.value.lock
    end

    # Identical to `#wait` but the current fiber will be resumed automatically
    # when `timeout` is reached. Returns `true` if the timeout was reached,
    # `false` otherwise.
    def wait(mutex : Pointer(Mutex), timeout : Time::Span) : Bool
      reached_timeout = false
      current = Fiber.current

      Syn.timeout_acquire(current)
      @spin.synchronize { @waiting.push(current) }
      mutex.value.unlock

      ::sleep(timeout)

      if Syn.timeout_cas?(current)
        reached_timeout = true
        @spin.synchronize { @waiting.delete(current) }
      else
        # another thread enqueued the current fiber
        ::sleep
      end

      Syn.timeout_release(current)
      mutex.value.lock

      reached_timeout
    end

    # Enqueues one waiting fiber. Does nothing if there aren't any waiting
    # fiber.
    def signal : Nil
      if fiber = @spin.synchronize { @waiting.shift? }
        fiber.enqueue
      end
    end

    # Enqueues all waiting fibers at once. Does nothing if there aren't any
    # waiting fiber.
    def broadcast : Nil
      @spin.synchronize do
        @waiting.each(&.enqueue)
        @waiting.clear
      end
    end
  end
end
