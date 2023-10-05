require "./core/condition_variable"

# Synchronize execution of concurrently running fibers.
#
# This can be used to replace polling with a waiting list that can be resumed
# when resources are available, while still behaving inside a mutually
# exclusive context: when a waiting fiber is resumed, the mutex will be
# locked again.
#
# Can also be used as a notification system without a mutex. In which case
# the mutex must be `nil` so it won't be unlocked nor locked.
class Syn::ConditionVariable
  def initialize
    @condition_variable = Core::ConditionVariable.new
  end

  # Suspends the current fiber. The mutex is unlocked before the fiber is
  # suspended (the current fiber must be holding the lock) and will be locked
  # again after the fiber is resumed and before the function returns.
  #
  # If you don't need a mutex you can pass `nil` and the condition variable will
  # act as a notification system.
  def wait(mutex : Mutex?) : Nil
    if mutex
      @condition_variable.wait(pointerof(mutex.@mutex))
    else
      @condition_variable.wait(nil)
    end
  end

  # Identical to `#wait` but the current fiber will be resumed automatically
  # when `timeout` is reached. Returns `true` if the timeout was reached,
  # `false` otherwise.
  @[Experimental("The timeout feature is experimental.")]
  def wait(mutex : Mutex?, timeout : Time::Span) : Bool
    if mutex
      @condition_variable.wait(pointerof(mutex.@mutex), timeout)
    else
      @condition_variable.wait(nil, timeout)
    end
  end

  # Enqueues one waiting fiber. Does nothing if there aren't any waiting fiber.
  def signal : Nil
    @condition_variable.signal
  end

  # Enqueues all waiting fibers at once. Does nothing if there aren't any
  # waiting fiber.
  def broadcast : Nil
    @condition_variable.broadcast
  end
end
