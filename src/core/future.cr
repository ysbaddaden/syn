require "./condition_variable"
require "../error"

module Syn::Core
  # An object that will eventually hold a value.
  #
  # Can be used to ask an `Agent` to compute a value asynchronously, while the
  # current fiber continues to do other things, yet be able to retrieve or wait
  # until the value is available.
  #
  # TODO: report a failure (with an optional exception)
  struct Future(T)
    @error : Exception | String | Nil

    enum State : UInt8
      INDETERMINATE = 0_u8
      RESOLVED      = 1_u8
      FAILED        = 2_u8
    end

    def initialize
      {% raise "Can't create future for Nil type" if T == Nil %}
      {% raise "Can't create future for nilable type" if T.union? && T.union_types.any? { |t| t == Nil } %}
      @notification = ConditionVariable.new
      @error = nil
      @value = uninitialized T
      @state = Atomic(State).new(State::INDETERMINATE)
    end

    # Sets the value and wakes up pending fibers.
    #
    # TODO: raise if the future has already been resolved
    def set(value : T) : T
      @value = value
      self.state = State::RESOLVED
      value
    end

    # Report a failure when trying to resolve the future. Wakes up pending
    # fibers.
    #
    # TODO: raise if the future has already been resolved
    def fail(error : Exception | String | Nil = nil) : Nil
      @error = error
      self.state = State::FAILED
    end

    # Returns the value if it was resolved. Returns `nil` otherwise without
    # blocking. Raises an exception if the future has failed.
    def get? : T?
      __get { return nil }
    end

    # Blocks the current fiber until the value is resolved.
    def get : T
      __get { @notification.wait(nil) }
    end

    # Blocks the current fiber until the value is resolved or timeout is
    # reached, in which case it returns `nil`.
    def get(timeout : Time::Span) : T?
      __get { return if @notification.wait(nil, timeout) }
    end

    @[AlwaysInline]
    private def __get(&)
      state = self.state

      if state == State::INDETERMINATE
        yield
        state = self.state
      end

      case state
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
    private def state : State
      result = @state.get
      {% unless flag?(:interpreted) %} Atomic::Ops.fence(:sequentially_consistent, false) {% end %}
      result
    end

    @[AlwaysInline]
    private def state=(state : State) : Nil
      {% unless flag?(:interpreted) %} Atomic::Ops.fence(:sequentially_consistent, false) {% end %}
      @state.set(state)
      {% unless flag?(:interpreted) %} Atomic::Ops.fence(:sequentially_consistent, false) {% end %}
      @notification.broadcast
    end
  end
end
