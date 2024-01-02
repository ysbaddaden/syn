module Syn::Core
  # Similar to `Atomic::Flag` but with acquire/release memory ordering (instead
  # of sequentially consistent) and explicit memory barriers (fences) on
  # architectures that need one (e.g. ARMv6 and ARMv7).
  struct AtomicLock
    def initialize
      @value = 0_u8
    end

    # Tries to acquire the lock. The operation is atomic, and any operation that
    # happens _after_ the acquire won't be reordered before the acquire, either
    # during compilation or live at runtime on weak CPU architectures.
    def acquire? : Bool
      ret = Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :acquire, false) == 0_u8
      {% if flag?(:arm) %} Syn.fence(:acquire) if ret {% end %}
      ret
    end

    # Returns true if the lock was previously acquired.
    def acquired? : Bool
      Atomic::Ops.load(pointerof(@value), :sequentially_consistent, true) == 1_u8
    end

    # Releases the lock. The operation is atomic, and any operation that happens
    # _before_ the release won't be reordered after the release, either during
    # compilation or live at runtime on weak CPU architectures.
    def release : Nil
      Atomic::Ops.store(pointerof(@value), 0_u8, :release, true)

      # armv6 / armv7 also need an explicit memory barrier
      {% if flag?(:arm) %} Syn.fence(:release) {% end %}
    end
  end
end
