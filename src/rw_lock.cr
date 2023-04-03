require "./core/mutex"
require "./core/condition_variable"

# A many readers, mutually exclusive writer lock.
#
# Allows readers to run concurrently but ensures that they will never run
# concurrently to a writer. Writers are mutually exclusive to both readers
# and writers.
#
# FIXME: untested
class Syn::RWLock
  @mutex : Core::Mutex
  @condition_variable : Core::ConditionVariable
  @readers_count : UInt32

  def initialize
    @mutex = Core::Mutex.new(:unchecked)
    @condition_variable = Core::ConditionVariable.new
    @readers_count = 0_u32
  end

  def lock_read : Nil
    @mutex.synchronize do
      @readers_count += 1
    end
  end

  @[Experimental("The timeout feature is experimental.")]
  def lock_read(timeout : Time::Span) : Bool
    @mutex.synchronize(timeout) do
      @readers_count += 1
    end
  end

  def lock_read(&) : Nil
    lock_read
    yield
  ensure
    unlock_read
  end

  @[Experimental("The timeout feature is experimental.")]
  def lock_read(timeout : Time::Span, &) : Bool
    if lock_read(timeout)
      begin
        yield
      ensure
        unlock_read
      end
      true
    else
      false
    end
  end

  def unlock_read : Nil
    @mutex.synchronize do
      if (@readers_count -= 1) == 0
        @condition_variable.signal
      end
    end
  end

  def lock_write : Nil
    @mutex.lock
    until @readers_count == 0
      @condition_variable.wait(pointerof(@mutex))
    end
  end

  @[Experimental("The timeout feature is experimental.")]
  def lock_write(timeout : Time::Span) : Bool
    @mutex.lock
    until @readers_count == 0
      @condition_variable.wait(pointerof(@mutex), timeout)
    end
  end

  def lock_write(&) : Nil
    lock_write
    yield
  ensure
    unlock_write
  end

  @[Experimental("The timeout feature is experimental.")]
  def lock_write(timeout : Time::Span, &) : Bool
    if lock_write(timeout)
      begin
        yield
      ensure
        unlock_write
      end
      true
    else
      false
    end
  end

  def unlock_write : Nil
    @condition_variable.signal
    @mutex.unlock
  end
end
