require "../syn"
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
    def wait(mutex : Pointer(Mutex), timeout : Time::Span, *, relock_on_timeout : Bool = true) : Bool
      current = Fiber.current

      Syn.timeout_acquire(current)
      @spin.synchronize { @waiting.push(current) }
      mutex.value.unlock

      if reached_timeout = Syn.sleep(current, timeout)
        @spin.synchronize { @waiting.delete(current) }
      end
      Syn.timeout_release(current)

      if !reached_timeout || relock_on_timeout
        mutex.value.lock
      end
      reached_timeout
    end

    # Enqueues one waiting fiber. Does nothing if there aren't any waiting
    # fiber.
    def signal : Nil
      while fiber = @spin.synchronize { @waiting.shift? }
        if Syn.timeout_resumeable?(fiber)
          fiber.enqueue
          return
        end
      end
    end

    # Enqueues all waiting fibers at once. Does nothing if there aren't any
    # waiting fiber.
    def broadcast : Nil
      @spin.synchronize do
        @waiting.each do |fiber|
          if Syn.timeout_resumeable?(fiber)
            fiber.enqueue
          end
        end
        @waiting.clear
      end
    end
  end
end
