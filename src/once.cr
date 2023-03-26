# Similar to `Syn::Flag` but limited to a single usage: prevent a block
# of code to be invoked more than once, for example executing an initializer at
# most once.
#
# Relies on `:sequentially_consistent` memory ordering.
struct Syn::Once
  def initialize
    @value = 0_u8
  end

  def call(& : ->) : Nil
    first = Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :sequentially_consistent, false) == 0_u8

    {% unless flag?(:interpreted) %}
      Atomic::Ops.fence(:sequentially_consistent, false)
    {% end %}

    if first
      yield
    end
  end
end
