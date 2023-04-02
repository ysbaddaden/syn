require "../core_ext/fiber"

module Syn::Core
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

    struct Iterator
      def initialize(@head : Fiber?)
      end

      def each(& : Fiber ->) : Nil
        fiber = @head

        while fiber
          next_fiber = fiber.@__syn_next
          Atomic::Ops.fence(:sequentially_consistent, false) # needed ?!

          yield fiber

          fiber = next_fiber
        end
      end
    end

    def each : Iterator?
      Iterator.new(@head)
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
