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
      if Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :sequentially_consistent, false) == 0_u8
        {% if flag?(:arm) %} Syn.fence(:sequentially_consistent) {% end %}
        yield
      end
    end
  end
end
