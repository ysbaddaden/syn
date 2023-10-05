require "../syn"
require "./lockable"
require "./spin_lock"
require "./wait_list"

module Syn::Core
  # Synchronize execution of concurrently running fibers.
  #
  # This can be used to replace polling with a waiting list that can be resumed
  # when resources are available, while still behaving inside a mutually
  # exclusive context: when a waiting fiber is resumed, the lockable will be
  # locked.
  #
  # Can also be used as a notification system without a lockable. In which case
  # the lockable must be `nil` (or `Pointer(Syn::Lockable).null`) and the
  # lockable won't be unlocked nor locked.
  struct ConditionVariable
    def initialize
      @spin = SpinLock.new
      @waiting = WaitList.new
    end

    # Suspends the current fiber. The lockable is unlocked before the fiber is
    # suspended (the current fiber must be holding the lock) and will be locked
    # again after the fiber is resumed and before the function returns.
    #
    # In case you don't need a lockable you can pass `nil` and the condition
    # variable will act as a notification system.
    def wait(lockable : Pointer(Lockable)?) : Nil
      current = Fiber.current
      @spin.synchronize { @waiting.push(current) }
      lockable.try(&.value.unlock)
      ::sleep
      lockable.try(&.value.lock)
    end

    # Identical to `#wait` but the current fiber will be resumed automatically
    # when `timeout` is reached. Returns `true` if the timeout was reached,
    # `false` otherwise.
    @[Experimental("The timeout feature is experimental.")]
    def wait(lockable : Pointer(Lockable)?, timeout : Time::Span, *, relock_on_timeout : Bool = true) : Bool
      current = Fiber.current

      Syn.timeout_acquire(current)
      @spin.synchronize { @waiting.push(current) }
      lockable.try(&.value.unlock)

      if reached_timeout = Syn.sleep(current, timeout)
        @spin.synchronize { @waiting.delete(current) }
      end
      Syn.timeout_release(current)

      if !reached_timeout || relock_on_timeout
        lockable.try(&.value.lock)
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
      iterator = @spin.synchronize do
        @waiting.each.tap { @waiting.clear }
      end

      iterator.each do |fiber|
        fiber.enqueue if Syn.timeout_resumeable?(fiber)
      end
    end
  end
end
