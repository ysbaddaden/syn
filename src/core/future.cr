require "./condition_variable"

module Syn::Core
  # An object that will eventually hold a value.
  #
  # Can be used to ask an `Agent` to compute a value asynchronously, while the
  # current fiber continues to do other things, yet be able to retrieve or wait
  # until the value is available.
  struct Future(T)
    def initialize
      {% raise "Can't create Atomic for Nil type" if T == Nil %}
      {% raise "Can't create Atomic for nilable type" if T.union? && T.union_types.any? { |t| t == Nil } %}
      @notification = ConditionVariable.new
      @value = uninitialized T
      @resolved = Atomic(UInt8).new(0)
    end

    # Sets the value and wakes up pending fibers.
    #
    # TODO: raise if the value has already been resolved (?)
    def set(value : T) : T
      @value = value
      Atomic::Ops.fence(:sequentially_consistent, false)
      @resolved.set(1)
      Atomic::Ops.fence(:sequentially_consistent, false)
      @notification.broadcast
      value
    end

    # Returns the value if it was resolved. Returns `nil` otherwise without
    # blocking.
    def get? : T?
      @value if resolved?
    end

    # Blocks the current fiber until the value is resolved.
    def get : T
      @notification.wait(nil) unless resolved?
      @value
    end

    # Blocks the current fiber until the value is resolved or timeout is
    # reached, in which case it returns `nil`.
    def get(timeout : Time::Span) : T?
      return @value if resolved?
      @value unless @notification.wait(nil, timeout)
    end

    private def resolved? : Bool
      if result = @resolved.get == 1
        Atomic::Ops.fence(:sequentially_consistent, false)
      end
      result
    end
  end
end
