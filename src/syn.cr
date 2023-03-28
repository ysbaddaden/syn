module Syn
  # OPTIMIZE: consider using Atomic::Ops directly to specify acquire/release
  #           memory ordering instead of sequentially consistent

  # :nodoc:
  @[AlwaysInline]
  def self.sleep(fiber : Fiber, timeout : Time::Span) : Bool
    fiber.timeout(timeout, Syn::TimeoutAction.new(timeout))
    ::sleep # reschedule

    # 1_u8: doesn't make sense
    # 2_u8: another thread enqueued the fiber (direct resume)
    # 3_u8: reached timeout (event loop -> TimeoutAction resume)
    if fiber.@__syn_timeout.get == 3_u8
      true
    else
      fiber.cancel_timeout
      false
    end
  end

  # :nodoc:
  @[AlwaysInline]
  def self.timeout_acquire(fiber : Fiber) : Nil
    fiber.@__syn_timeout.set(1_u8)
    {% unless flag?(:interpreted) %}
      Atomic::Ops.fence(:acquire, false)
    {% end %}
  end

  # :nodoc:
  @[AlwaysInline]
  def self.timeout_release(fiber : Fiber) : Nil
    fiber.@__syn_timeout.set(0_u8)
    {% unless flag?(:interpreted) %}
      Atomic::Ops.fence(:release, false)
    {% end %}
  end

  # :nodoc:
  @[AlwaysInline]
  def self.timeout_cas?(fiber : Fiber, to : UInt8) : Bool
    _, success = fiber.@__syn_timeout.compare_and_set(1_u8, to)
    success
  end

  # :nodoc:
  @[AlwaysInline]
  def self.timeout_resumeable?(fiber : Fiber) : Bool
    fiber.@__syn_timeout.get == 0_u8 || timeout_cas?(fiber, 2_u8)
  end

  # :nodoc:
  class TimeoutAction < Channel::TimeoutAction
    def time_expired(fiber : Fiber) : Nil
      if Syn.timeout_cas?(fiber, 3_u8)
        Crystal::Scheduler.enqueue(fiber)
      end
      fiber.cancel_timeout
    end
  end
end
