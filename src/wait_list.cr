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

  # :nodoc:
  @__syn_next : Fiber?

  # :nodoc:
  def __syn_next=(value : Fiber?)
    @__syn_next = value
  end
end

module Syn
  # Holds a singly linked list of pending `Fiber`. It is used to build all the
  # other concurrency objects. Implemented as a FIFO list. Assumes that a
  # `Fiber` can only ever be in a single `WaitList` at any given time, and will
  # be suspended while it's in the list.
  struct WaitList
    # NOTE: tail is only used when head is set to append fibers to the list,
    #       which allows some optimization: no need to check or update it in
    #       most situations (outside of `#push`). We also don't need to clear
    #       the `@__syn_next` attribute either (it will be overwritten the next
    #       time it's pushed to a wait list).

    # TODO: we might still want to clear tail and `@__syn_next` to avoid keeping
    #       hard references to dead fibers which may impact GC?

    @head : Fiber?
    @tail : Fiber?

    def push(fiber : Fiber) : Nil
      fiber.__syn_next = nil

      if @head
        @tail = @tail.unsafe_as(Fiber).__syn_next = fiber
      else
        @tail = @head = fiber
      end
    end

    def shift? : Fiber?
      if fiber = @head
        @head = fiber.@__syn_next
        # fiber.@__syn_next = nil
        fiber
      end
    end

    def each(& : Fiber ->) : Nil
      fiber = @head
      while fiber
        yield fiber
        fiber = fiber.@__syn_next
      end
    end

    def delete(fiber : Fiber) : Nil
      prev, curr = nil, @head

      # search item in list
      until curr == fiber
        prev, curr = curr, curr.unsafe_as(Fiber).@__syn_next
      end

      # not in list
      unless curr
        # fiber.@__syn_next = nil
        return
      end

      if prev
        # removing inner or tail
        prev.__syn_next = curr.@__syn_next
      else
        # removing head
        @head = curr.@__syn_next
      end

      if fiber == @tail
        # removing tail
        @tail = prev
      end

      # fiber.@__syn_next = nil
    end

    def clear : Nil
      @head = nil
      # @tail = nil
    end
  end
end
