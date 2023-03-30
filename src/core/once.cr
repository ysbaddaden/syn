module Syn::Core
  # Similar to `AtomicLock` but limited to a single usage: prevent a block of
  # code to be invoked more than once, for example executing an initializer at
  # most once.
  #
  # Relies on `:sequentially_consistent` memory ordering.
  struct Once
    def initialize
      @value = 0_u8
    end

    def call(& : ->) : Nil
      old_value = Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :sequentially_consistent, false)

      {% unless flag?(:interpreted) %}
        Atomic::Ops.fence(:sequentially_consistent, false)
      {% end %}

      if old_value == 0_u8
        yield
      end
    end
  end
end
