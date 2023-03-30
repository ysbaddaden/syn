module Syn::Core
  # Similar to `Atomic::Flag` but adds memory barriers (fences) in addition
  # to the atomic instructions, and relies on the acquire/release memory
  # ordering that should be suitable for locks.
  #
  # Basically, the atomic instructions tell the CPU to use an atomic operand on
  # the CPU and usually their memory ordering also serves as hints to the
  # compiler (here LLVM) to not reorder instructions across the atomic. The
  # fences add another level of protection against weak CPU architectures (such
  # as ARM), telling them to not reorder instructions across the fences at
  # runtime.
  #
  # The memory fences should be noop and optimized away on non weak CPU
  # architectures such as x86/64.
  struct AtomicLock
    def initialize
      @value = 0_u8
    end

    # Acquires the lock. The operation is atomic, and any operation that happens
    # _after_ the acquire won't be reordered before the acquire, either during
    # compilation or live at runtime on weak CPU architectures.
    def acquire? : Bool
      if Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :acquire, false) == 0_u8
        {% unless flag?(:interpreted) %} Atomic::Ops.fence(:acquire, false) {% end %}
        true
      else
        false
      end
    end

    # Releases the lock. The operation is atomic, and any operation that happens
    # _before_ the release won't be reordered after the release, either during
    # compilation or live at runtime on weak CPU architectures.
    def release : Nil
      Atomic::Ops.store(pointerof(@value), 0_u8, :release, true)
      {% unless flag?(:interpreted) %} Atomic::Ops.fence(:release, false) {% end %}
    end
  end
end
