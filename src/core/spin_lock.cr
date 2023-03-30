require "./atomic_lock"

module Syn::Core
  # Tries to acquire an atomic lock by spining, trying to avoid slow thread
  # context switches that involve the kernel scheduler but eventually fallback
  # to yielding to another thread, to avoid spinning (and thus burning) a CPU
  # that would be counter-productive (scheduler may believe the thread is doing
  # some heavy computation and delay it's suspension).
  #
  # This is a public alternative to the private Crystal::SpinLock in stdlib.
  # That beind said, you're not supposed to ever need it.
  #
  # The implementation is a NOOP until the program has enabling MT during
  # compilation (i.e. `-Dpreview_mt` flag).
  struct SpinLock
    {% if flag?(:preview_mt) %}
      # :nodoc:
      THRESHOLD = 100

      @lock = AtomicLock.new

      def lock : Nil
        until @lock.acquire?
          # fixed busy loop to avoid a context switch:
          count = THRESHOLD
          until (count -= 1) == 0
            return if @lock.acquire?
          end

          # fallback to thread context switch (slow path):
          Thread.yield
        end
      end

      def unlock : Nil
        @lock.release
      end
    {% else %}
      def lock : Nil
      end

      def unlock : Nil
      end
    {% end %}

    # Locks, yields and unlocks.
    #
    # NOTE: make sure that the block doesn't execute anything more than
    # necessary, since concurrent threads will be blocked for its whole
    # duration!
    def synchronize(& : -> U) : U forall U
      lock
      yield
    ensure
      unlock
    end
  end
end
