require "./spin_lock"
require "./condition_variable"
require "../error"

module Syn::Core
  # An object that will eventually hold a value.
  #
  # Can be passed to another fiber to compute a value asynchronously, while the
  # current fiber continues to do other things, yet be able to retrieve or wait
  # until the value is available.
  struct Future(T)
    @error : Exception | String | Nil

    # :nodoc:
    enum State : UInt8
      INDETERMINATE = 0_u8
      RESOLVED      = 1_u8
      FAILED        = 2_u8
    end

    def initialize
      {% raise "Can't create future for Nil type" if T == Nil %}
      {% raise "Can't create future for nilable type" if T.union? && T.union_types.any? { |t| t == Nil } %}
      @state = Atomic(State).new(State::INDETERMINATE)
      @spin = SpinLock.new
      @condition = ConditionVariable.new
      @error = nil
      @value = uninitialized T
    end

    # Sets the value and wakes up pending fibers.
    def set(value : T) : T
      @spin.lock
      check_unresolved!
      @value = value
      @state.set State::RESOLVED
      @condition.broadcast
      @spin.unlock
      value
    end

    # Sets the future as failed and wakes up pending fibers.
    def fail(error : Exception | String | Nil = nil) : Nil
      @spin.lock
      check_unresolved!
      @error = error
      @state.set State::FAILED
      @condition.broadcast
      @spin.unlock
    end

    # Returns the value if it was resolved. Returns `nil` otherwise without
    # blocking. Raises an exception if the future has failed.
    def get? : T?
      unsafe_get if resolved?
    end

    # Blocks the current fiber until the value is resolved and returned. Raises
    # an exception if the future has failed.
    def get : T
      unless resolved?
        {% if flag?(:preview_mt) %}
          @spin.lock
          unless resolved?
            # OPTIMIZE: we don't need to re-lock the lockable on resume (but we
            #           must only unlock after pushing the current fiber to the
            #           wait list)
            @condition.wait(pointerof(@spin))
          end
          @spin.unlock
        {% else %}
          @condition.wait(nil)
        {% end %}
      end

      # safe: the future has been resolved
      unsafe_get
    end

    # Blocks the current fiber until the value is resolved or timeout is
    # reached, in which case it returns `nil`. Raises an exception if the future
    # has failed.
    def get(timeout : Time::Span) : T?
      unless resolved?
        {% if flag?(:preview_mt) %}
          @spin.lock
          unless resolved?
            if @condition.wait(pointerof(@spin), timeout, relock_on_timeout: false)
              return # reached timeout
            end
          end
          @spin.unlock
        {% else %}
          if @condition.wait(nil, timeout)
            return # reached timeout
          end
        {% end %}
      end

      # safe: the future has been resolved
      unsafe_get
    end

    @[AlwaysInline]
    private def unsafe_get
      case @state.get
      in State::RESOLVED
        @value
      in State::FAILED
        raise_exception
      in State::INDETERMINATE
        raise "unreachable"
      end
    end

    @[AlwaysInline]
    private def raise_exception : NoReturn
      case error = @error
      in Exception
        raise error
      in String
        raise FailedError.new(error)
      in Nil
        raise FailedError.new
      end
    end

    @[AlwaysInline]
    private def resolved? : Bool
      @state.get != State::INDETERMINATE
    end

    @[AlwaysInline]
    private def check_unresolved!
      if resolved?
        @spin.unlock
        raise AlreadyResolved.new if resolved?
      end
    end
  end
end
