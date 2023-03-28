# require "fiber"

# :nodoc:
class Fiber
  # Assumes that a `Fiber` can only ever be blocked once in which case it's
  # added to an `Syn::WaitList` and suspended, then removed from the list
  # to then be enqueued again.
  #
  # You should never use this property outside of `Syn::WaitList`! Or you must
  # assume the same behavior: add to list -> suspend -> remove from list ->
  # resume.
  #
  # NOTE: there would be a race condition with MT:
  #
  # - Thread 1 pushes a Fiber to the WaitList
  # - Thread 2 removes the Fiber from the WaitList
  # - Thread 2 resumes the Fiber < ERR: trying to resume running fiber
  # - Thread 1 suspends the Fiber
  #
  # But the current MT implementation ties a Fiber to a thread, so even if
  # Thread 2 tried to resume the fiber, it would actually enqueue it back to
  # Thread 1's queue, which in the worst case is still running the actual Fiber
  # (and will resume it *later*).
  #
  # All this to say that when using a WaitList you must never resume a Fiber
  # directly, but always enqueue it, so it will be properly resumed (later).
  #
  # If Crystal ever implements job stealing, this race conditions will be
  # present, and the scheduler will have to take care of it (e.g. using
  # `Fiber#resumable?`.
  @__syn_next : Fiber?

  # Atomic to know whether the fiber has been suspended with a timeout, and also
  # resolve on MT who shall wakeup the fiber since the timeout may run in
  # parallel to another thread trying to enqueue the fiber.
  #
  # 0_u8: no timeout (default)
  # 1_u8: set when expecting timeout
  # 2_u8: the fiber that can cmpxchg from 1 to 2 executes the operation (timed
  # out or enqueue)
  @__syn_timeout = Atomic(UInt8).new(0_u8)

  # :nodoc:
  def __syn_next=(value : Fiber?)
    @__syn_next = value
  end
end
