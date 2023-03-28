require "./spin_lock"
require "./wait_list"
require "../error"

module Syn::Core
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
  #   If the mutex is to protect a shared data structure, and its usage is
  #   restricted to an object's internals, you may consider unchecked mutexes
  #   for a limited performance gain.
  #
  # - **Reentrant** mutexes also memorize the fiber that locked the mutex; the
  #   same fiber is allowed to re-lock the mutex up to 255 times (afterwards an
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
  #
  # TODO: check whether the owning fiber is still alive or not (i.e. EOWNERDEAD)
  struct Mutex
    enum Type : UInt8
      Checked
      Unchecked
      Reentrant
    end

    # warning: don't move these definitions to not change the struct size!
    @blocking : WaitList
    @locked_by : Fiber?
    @held : Flag
    @spin : SpinLock
    @type : Type
    @counter : UInt8

    def initialize(@type : Type = :checked)
      @held = Flag.new
      @spin = SpinLock.new
      @blocking = WaitList.new
      @counter = 0_u8
    end

    # Returns true if the lock could be acquired, otherwise immediately returns
    # false without blocking.
    #
    # Merely returns false whenever the lock if already held. Doesn't check if
    # the current fiber currently holds the lock, doesn't raise and also doesn't
    # increment the counter for reentrant mutexes (unless it's the initial
    # lock).
    def try_lock? : Bool
      # we're modifying @locked_by and @counter depending on @held which
      # sounds unsafe _but_ the current fiber is holding the lock and
      # checking for deadlock or reentrancy isn't an issue because the
      # current fiber won't try to lock or unlock (it's busy setting the
      # following ivars)
      if @held.test_and_set
        unless @type.unchecked?
          @locked_by = Fiber.current
          @counter += 1 if @type.reentrant?
        end
        return true
      end

      if @type.reentrant? && @locked_by == Fiber.current
        prevent_reentrancy_overflow! {}
        @counter += 1
        return true
      end

      false
    end

    # Acquires the lock, suspending the current fiber until the lock can be
    # acquired.
    #
    # If the mutex is unchecked, trying to re-lock while the current fiber is
    # already holding the lock will result in a deadlock. If checked it will
    # raise an `Error`. If reentrant, the counter will be incremented and the
    # method will return.
    def lock : Nil
      __lock do |current|
        @blocking.push(current)
        @spin.unlock
        ::sleep
        @spin.lock
      end
    end

    # Identical to `#lock` but aborts if the lock couldn't be acquired until
    # timeout is reached, in which case it returns false (failed to acquire
    # lock). Returns true if the lock was acquired.
    def lock(timeout : Time::Span) : Bool
      expires_at = Time.monotonic + timeout
      reached_timeout = false

      __lock do |current|
        # suspend for the remaining of the timeout (may be resumed earlier)
        #
        # uses an atomic to declare that we're expecting a timeout (1) and to
        # resolve a race condition where the timeout event would be handled in
        # thread A while thread B dequeued the same fiber from @blocking and is
        # about to resume it (only enqueue if the atomic is 0 or CAS 1 -> 2).
        Syn.timeout_acquire(current)
        @blocking.push(current)
        @spin.unlock

        ::sleep(expires_at - Time.monotonic)

        if Syn.timeout_cas?(current)
          reached_timeout = true
          @spin.lock
          @blocking.delete(current)
        else
          # another thread enqueued the current fiber
          sleep
          @spin.lock
        end
        Syn.timeout_release(current)

        break if reached_timeout
      end

      reached_timeout
    end

    private def __lock(&) : Nil
      # try to acquire lock (without spin lock):
      return if try_lock?

      current = Fiber.current

      # need thread exclusive access to re-check @held then manipulate @blocking
      # (and other ivars) based on the CAS result
      @spin.lock

      # must loop because a wakeup may be concurrential, and another `#lock` or
      # `#try_lock?` may have already acquired the lock
      until try_lock?
        unless @type.unchecked?
          if @locked_by == current
            if @type.reentrant?
              return prevent_reentrancy_overflow! { @spin.unlock }
            end

            @spin.unlock
            raise Error.new("Can't re-lock mutex from the same fiber (deadlock)")
          end
        end

        yield current
      end

      @spin.unlock
    end

    private def prevent_reentrancy_overflow!(&) : Nil
      if @counter == 255
        yield
        raise Error.new("Can't re-lock reentrant mutex more than 255 times")
      end
    end

    # Releases the lock.
    #
    # If unchecked, any fiber can unlock the mutex and the mutex doesn't even
    # need to be locked. If checked or reentrant, the mutex must be locked and
    # only the fiber holding the lock is allowed otherwise `Error` exceptions
    # will raised. If reentrant the counter will be decremented and the lock
    # only released when the counter reaches zero (i.e. you must call `#unlock`
    # as many times as `#lock` was called.
    def unlock : Nil
      # need thread exclusive access because we modify multiple values (@held,
      # @blocking, @locked_by, @counter)
      @spin.lock

      # NOTE: we manually unlock the spinner _before_ each return/raise instead
      #       of doing it once in an ensure block because we don't want to hold
      #       the lock for longer than necessary. Raising an exception is a slow
      #       and expensive operation, and it would ruin performance.

      unless @type.unchecked?
        if @locked_by.nil?
          @spin.unlock
          raise Error.new("Can't unlock a mutex that isn't locked.")
        end

        unless @locked_by == Fiber.current
          @spin.unlock
          raise Error.new("Can't unlock mutex locked by another fiber.")
        end

        if @type.reentrant?
          unless (@counter -= 1) == 0
            @spin.unlock
            return
          end
        end

        @locked_by = nil
      end

      # actual unlock
      @held.clear

      wakeup_next? do |fiber|
        @spin.unlock
        fiber.enqueue
        return
      end

      @spin.unlock
    end

    # Yields next blocking fiber (taking care of parallelism issues).
    private def wakeup_next?(&) : Nil
      while fiber = @blocking.shift?
        if fiber.@__syn_timeout.get == 0_u8 ||
            fiber.@__syn_timeout.compare_and_set(1_u8, 2_u8).last
          yield fiber
          break
        end
      end
    end

    # Acquires the lock, yields, then releases the lock, even if the block
    # raised an exception.
    def synchronize(& : -> U) : U forall U
      lock
      yield
    ensure
      unlock
    end

    # Identical to `#synchronize` but aborts if the lock couldn't be acquired
    # until timeout is reached, in which case it returns false.
    #
    # NOTE: unlike `#synchronize` it doesn't return the block's value!
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
