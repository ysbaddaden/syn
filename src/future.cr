require "./core/future"

module Syn
  # An object that will eventually hold a value.
  #
  # Can be passed to another fiber to compute a value asynchronously, while the
  # current fiber continues to do other things, yet be able to retrieve or wait
  # until the value is available.
  class Future(T)
    def initialize
      @future = Core::Future(T).new
    end

    # Sets the value and wakes up pending fibers.
    #
    # TODO: raise if the future has already been resolved/failed
    def set(value : T) : T
      @future.set(value)
    end

    # Report a failure when trying to resolve the future. Wakes up pending
    # fibers.
    #
    # TODO: raise if the future has already been resolved/failed
    def fail(error : Exception | String | Nil = nil) : Nil
      @future.fail(error)
    end

    # Returns the value if it was resolved. Returns `nil` otherwise without
    # blocking. Raises an exception if the future has failed.
    def get? : T?
      @future.get?
    end

    # Blocks the current fiber until the value is resolved. Raises an exception
    # if the future has failed.
    def get : T
      @future.get
    end

    # Blocks the current fiber until the value is resolved or timeout is
    # reached, in which case it returns `nil`. Raises an exception if the future
    # has failed.
    @[Experimental("The timeout feature is experimental.")]
    def get(timeout : Time::Span) : T?
      @future.get(timeout)
    end
  end
end
