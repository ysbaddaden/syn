require "../core_ext/fiber"

module Syn::Core
  # Holds a singly linked list of pending `Fiber`. It is used to build all the
  # other concurrency objects. Implemented as a FIFO list. Assumes that a
  # `Fiber` can only ever be in a single `WaitList` at any given time, and will
  # be suspended while it's in the list.
  #
  # TODO: See Crystal::PointerLinkedList(T) and consider something that would
  #       allocate the nodes on the stack while we wait, which would avoid
  #       extending Fiber.
  #
  # TODO: Consider a doubly linked list: it would negatively impact push but
  #       make delete faster (we delete on timeout).
  #
  # TODO: Consider an internal optimistic wait-free linked list (using atomics)
  #       instead of requiring an external lock to protect the list (MT).
  struct WaitList
    # Tail is only used when head is set to append fibers to the list. This
    # could allow some optimization: no need to check or update it in most
    # situations (outside of `#push`); we also don't need to clear the
    # `@__syn_next` property either (it will be overwritten the next time it's
    # pushed to a wait list).
    #
    # Yet, we should still clear `tail` and `@__syn_next` to avoid keeping hard
    # references to dead fibers, which could lead the GC to keep some fiber
    # objects when it could reclaim the memory.

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
        fiber.__syn_next = nil # not needed but avoids HEAP pointer (GC)
        fiber
      end
    end

    def each(& : Fiber ->) : Nil
      fiber = @head
      while fiber
        next_fiber = fiber.@__syn_next
        yield fiber
        fiber = next_fiber
      end
    end

    struct Iterator
      def initialize(@head : Fiber?)
      end

      def each(& : Fiber ->) : Nil
        fiber = @head

        while fiber
          next_fiber = fiber.@__syn_next
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
        fiber.__syn_next = nil # not needed but avoids HEAP pointer (GC)
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

      fiber.__syn_next = nil # not needed but avoids HEAP pointer (GC)
    end

    def consume_each(& : Fiber ->) : Nil
      fiber = @head

      while fiber
        next_fiber = fiber.@__syn_next
        yield fiber
        fiber.__syn_next = nil
        fiber = next_fiber
      end

      clear
    end

    def clear : Nil
      @head = nil
      @tail = nil # not needed but avoids HEAP pointer (GC)
    end
  end
end
