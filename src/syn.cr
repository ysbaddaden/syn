module Syn
  # NOTE: the following methods would be somewhat useless if Atomic allowed to
  #       specify memory ordering and put memory barriers (fence).

  # OPTIMIZE: consider using Atomic::Ops directly to specify acquire/release
  #           memory ordering instead of the enforced sequentially consistent of
  #           Atomic(T).

  # :nodoc:
  @[AlwaysInline]
  def self.timeout_acquire(fiber : Fiber) : Nil
    # Atomic::Ops.store(pointerof(fiber.@__syn_timeout), 1_u8, :acquire)
    fiber.@__syn_timeout.set(1_u8)
    {% unless flag?(:interpreted) %}
      Atomic::Ops.fence(:acquire, false)
    {% end %}
  end

  # :nodoc:
  @[AlwaysInline]
  def self.timeout_release(fiber) : Nil
    # Atomic::Ops.store(pointerof(fiber.@__syn_timeout), 0_u8, :release)
    fiber.@__syn_timeout.set(0_u8)
    {% unless flag?(:interpreted) %}
      Atomic::Ops.fence(:release, false)
    {% end %}
  end

  # :nodoc:
  @[AlwaysInline]
  def self.timeout_cas?(fiber) : Bool
    # _, success = Atomic::Ops.cmpxchg(pointerof(fiber.@__syn_timeout), 1_u8, 2_u8, :sequentially_consistent, :sequentially_consistent)
    _, success = fiber.@__syn_timeout.compare_and_set(1_u8, 2_u8)
    success
  end
end
