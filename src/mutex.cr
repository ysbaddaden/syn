require "./lock"
require "./spin_lock"
require "./wait_list"

module Syn
  class Error < Exception
  end

  # A Fiber aware, mutually exclusive lock.
  #
  # Prevents two or more fibers to access the same non concurrent piece of code
  # (e.g. mutating a shared object) at the same time.
  #
  # There are three types of mutexes.
  #
  # - **Checked** mutexes memorize the fiber that locked the mutex; trying to
  #   lock the mutex twice from the same fiber will raise an exception; trying
  #   to unlock from another mutex will also raise an exception.
  #
  #   Checked mutexes are the default type, and the only safe type of mutex.
  #
  # - **Unchecked** mutexes don't check for errors; trying to lock twice from
  #   the same fiber will deadlock; any fiber is allowed to unlock the mutex.
  #
  #   If the mutex is to protect a shared data structure, and its usage is limited
  #   to an object's internals, you'll may consider unchecked mutexes for a
  #   limited performance gain.
  #
  # - **Reentrant** mutexes also memorize the fiber that locked the mutex; the
  #   same fiber is allowed to re-lock the mutex up to 256 times (afterwards an
  #   exception will be raised). Only the fiber that locked the mutex is allowed
  #   to unlock the mutex, but it must unlock it has many times as it previously
  #   locked it to actually unlock it.
  #
  #   There are probably valid use cases for reentrant mutexes, but ideally you
  #   shouldn't never have to use them (there are better synchronization concepts
  #   for complex use cases). Yet, they might be useful temporary as a quick
  #   workaround to deadlocks?
  #
  # This is a smaller and fully contained alternative to the `::Mutex` class in
  # stdlib that doesn't allocate extraneous objects. It also exposes the quick
  # `#try_lock?` that won't block.
  struct Mutex
    enum Type : UInt8
      Checked
      Unchecked
      Reentrant
    end

    include Lock

    # warn: don't move the type definitions to avoid changing the struct size
    # these take 16+8 bytes on 64-bit / 8+4 bytes on 32-bit
    @blocking : WaitList
    @locked_by : Fiber?

    # the rest take 4 bytes:
    @type : Type
    @held : Flag
    @spin : SpinLock
    @counter : UInt8

    def initialize(type : Type = :checked)
      @blocking = WaitList.new
      @type = type
      @held = Flag.new
      @spin = SpinLock.new
      @counter = 0_u8
    end

    # Returns true if it acquired the lock, otherwise immediately returns false.
    #
    # Returns false even if the current fiber had previously acquired the lock,
    # but won't cause a deadlock situation.
    def try_lock? : Bool
      if @held.test_and_set
        @locked_by = Fiber.current unless @type.unchecked?
        true
      else
        false
      end
    end

    # Acquires the lock, suspending the current fiber until the lock can be
    # acquired.
    def lock : Nil
      __lock { @spin.suspend }
    end

    # Identical to `#lock` but aborts if the lock couldn't be acquired until
    # timeout is reached, in which case it returns false.
    def lock(timeout : Time::Span) : Bool
      expires_at = Time.monotonic + timeout

      __lock do
        # suspend for the remaining of the timeout (may be resumed earlier)
        reached_timeout = @spin.suspend(expires_at - Time.monotonic)
        return false if reached_timeout
      end

      true
    end

    private def __lock(&)
      # try to acquire lock (without spin lock)
      return if try_lock?

      current = Fiber.current

      # need exclusive access to re-check @held then manipulate @blocking based
      # on the CAS result
      @spin.lock

      # must loop because a wakeup may be concurrential, and another `#lock` or
      # `#try_lock` may have already acquired the lock
      until try_lock?
        unless @type.unchecked?
          if @locked_by == current
            if @type.reentrant?
              if @counter == UInt8::MAX
                raise Error.new("Deadlock: can't re-lock a reentrant mutex more than 256 times.")
              else
                @counter += 1
                return
              end
            end
            raise Error.new("Deadlock: tried to re-lock checked mutex.")
          end
        end

        @blocking.push(current)
        yield
      end
    ensure
      @spin.unlock
    end

    # Releases the lock. If the mutex is unchecked it can be unlocked from any
    # fiber, not just the one that acquired the lock, otherwise only the fiber
    # that acquired the lock can unlock it, and `Syn::Error` will be raised.
    #
    # Reentrant mutexes will have to call `#unlock` as many times as they called
    # `#lock` to really unlock the mutex.
    def unlock : Nil
      # need exclusive access because we modify both 'held' and 'blocking' that
      # could introduce a race condition with lock:
      @spin.lock

      unless @type.unchecked?
        unless @locked_by == Fiber.current
          raise Error.new("Tried to unlock mutex from another fiber")
        end
        if @type.reentrant? && (@counter -= 1) != 0
          return
        end
      end

      # removes the lock
      @held.clear

      # wakeup next blocking fiber (if any)
      if fiber = @blocking.shift?
        @spin.unlock
        fiber.enqueue
      else
        @spin.unlock
      end
    end

    # Identical to `#synchronize` but aborts if the lock couldn't be acquired
    # until timeout is reached, in which case it returns false.
    def synchronize(timeout : Time::Span, &) : Bool
      if lock(timeout)
        begin
          yield
        ensure
          unlock
        end
        true
      else
        false
      end
    end
  end
end
