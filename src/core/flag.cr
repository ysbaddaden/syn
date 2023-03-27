module Syn::Core
  # Alternative to `Atomic::Flag` that adds memory barriers (fences) in addition
  # to the atomic instructions + acquire/release memory ordering.
  #
  # Basically the atomic instructions tell the CPU to use an atomic operand on the
  # CPU and usually their memory ordering also serves as hints to the compiler
  # (here LLVM) to not reorder instructions across the atomic. The fences add
  # another level of protection against weak CPU architectures (such as ARM),
  # telling them to not reorder instructions across the fences at runtime.
  #
  # The memory fences should be noop and optimized away on non weak CPU
  # architectures such as x86/64.
  #
  # Relies on `:acquire` and `:release` memory ordering that should be well suited
  # for lock/unlock strategies.
  struct Flag
    def initialize
      @value = 0_u8
    end

    def test_and_set : Bool
      test = Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :acquire, false) == 0_u8
      {% unless flag?(:interpreted) %}
        Atomic::Ops.fence(:acquire, false)
      {% end %}
      test
    end

    def clear : Nil
      {% unless flag?(:interpreted) %}
        Atomic::Ops.fence(:release, false)
      {% end %}
      Atomic::Ops.store(pointerof(@value), 0_u8, :release, true)
    end
  end
end
