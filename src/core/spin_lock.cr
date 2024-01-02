require "./lockable"

module Syn::Core
  # This is a public alternative to the private Crystal::SpinLock in stdlib.
  # You're not supposed to ever need it. The implementation is a NOOP until MT
  # was enabled at compile time (i.e. `-Dpreview_mt` flag).
  #
  # Warning:
  # - failing to acquire the lock will block the current thread!
  # - acquiring the lock will block other threads waiting on the lock!
  #
  # The mutually exclusive running sections must be as small and fast as
  # possible, otherwise the program performance will be impacted!
  struct SpinLock
    include Lockable

    {% if flag?(:preview_mt) %}
      UNLOCKED = 0_i8
      LOCKED = 1_i8

      @m = Atomic(Int8).new(UNLOCKED)

      @[AlwaysInline]
      def lock : Nil
        if @m.swap(LOCKED) == UNLOCKED
          {% if flag?(:arm) %} Syn.fence(:acquire) {% end %}
        else
          lock_slow
        end
      end

      # This is based on Go's futex loop (but without the futex) which is
      # distributed under a BSD-like license. See:
      #
      # https://cs.opensource.google/go/go/+/refs/tags/go1.21.5:src/runtime/lock_futex.go;l=51
      # https://cs.opensource.google/go/go/+/refs/tags/go1.21.5:LICENSE
      @[NoInline]
      private def lock_slow : Nil
        # OPTIMIZE: only spin if NCPU > 1 && NPROCS > 1
        active_spin = 4
        passive_spin = 1

        loop do
          # try to lock, spinning
          active_spin.times do
            while @m.lazy_get == UNLOCKED
              if @m.swap(LOCKED) == UNLOCKED
                {% if flag?(:arm) %} Syn.fence(:acquire) {% end %}
                return
              end
            end

            # yield cpu (low power) to avoid burning the CPU and tricking
            # the OS scheduler from believing the current thread needs power
            30.times { Intrinsics.pause }
          end

          # try to lock, rescheduling
          passive_spin.times do
            while @m.lazy_get == UNLOCKED
              if @m.swap(LOCKED) == UNLOCKED
                {% if flag?(:arm) %} Syn.fence(:acquire) {% end %}
                return
              end
            end
            Thread.yield
          end
        end
      end

      @[AlwaysInline]
      def unlock : Nil
        @m.set(UNLOCKED)
        {% if flag?(:arm) %} Syn.fence(:release) {% end %}
      end

      @[AlwaysInline]
      def synchronize(& : -> U) : U forall U
        lock
        yield
      ensure
        unlock
      end
    {% else %}
      @[AlwaysInline]
      def lock : Nil
      end

      @[AlwaysInline]
      def unlock : Nil
      end

      @[AlwaysInline]
      def synchronize(& : -> U) : U forall U
        yield
      end
    {% end %}
  end
end
