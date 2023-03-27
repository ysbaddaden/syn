require "./flag"

# :nodoc:
lib LibC
  fun pthread_yield
end

module Syn::Core
  # Tries to acquire an atomic lock by spining, trying to avoid slow thread
  # context switches that involve the kernel scheduler. Eventually fallsback to
  # a pause or yielding threads.
  #
  # This is a public alternative to the private Crystal::SpinLock in stdlib.
  #
  # The implementation is a NOOP unless you specify the `preview_mt` compile
  # flag.
  struct SpinLock
    {% if flag?(:preview_mt) %}
      # :nodoc
      THRESHOLD = 100

      @flag = Flag.new

      def lock : Nil
        # fast path
        return if @flag.test_and_set

        # fixed busy loop to avoid a context switch:
        count = THRESHOLD
        until (count -= 1) == 0
          return if @flag.test_and_set
        end

        # blocking loop
        until @flag.test_and_set
          LibC.pthread_yield
          # Intrinsics.pause
        end
      end

      def unlock : Nil
        @flag.clear
      end
    {% else %}
      def lock : Nil
      end

      def unlock : Nil
      end
    {% end %}

    def suspend : Nil
      unlock
      ::sleep
      lock
    end

    def suspend(timeout : Time::Span) : Nil
      unlock
      ::sleep(timeout)
      lock
    end

    def synchronize(& : -> U) : U forall U
      lock
      yield
    ensure
      unlock
    end

    # Identical to `#synchronize` but aborts if the lock couldn't be acquired
    # until timeout is reached, in which case it returns false.
    # def synchronize(timeout : Time::Span, &) : Bool
    #   if lock(timeout)
    #     begin
    #       yield
    #     ensure
    #       unlock
    #     end
    #     true
    #   else
    #     false
    #   end
    # end
  end
end
