require "./core/wait_group"

# Suspend execution until other fibers are finished.
class Syn::WaitGroup
  def initialize(counter : Int32 = 0)
    @wg = Core::WaitGroup.new(counter)
  end

  # Increments the counter by how many fibers we want to wait for.
  #
  # Can be called at any time, allowing concurrent fibers to add more fibers to
  # wait for, but they must always do so before calling `#done` to decrement the
  # counter, to make sure that the counter may never inadvertently reach zero
  # before all fibers are done.
  def add(count : Int) : Nil
    @wg.add(count)
  end

  # Decrements the counter by one. Must be called by concurrent fibers once they
  # have finished processing. When the counter reaches zero, all waiting fibers
  # will be resumed.
  def done : Nil
    @wg.done
  end

  # Suspends the current fiber until the counter reaches zero, at which point
  # the fiber will be closed.
  #
  # Can be called from different fibers.
  def wait : Nil
    @wg.wait
  end

  # Same as `#wait` but only waits until `timeout` is reached. Returns `true` if
  # the counter reached zero; returns `false` if timeout was reached.
  @[Experimental("The timeout feature is experimental.")]
  def wait(timeout : Time::Span) : Bool
    @wg.wait(timeout)
  end
end
