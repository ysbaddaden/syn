require "./core/mutex"
require "./core/condition_variable"

@[Experimental("Relies on the experimental timeout feature.")]
class Syn::Pool(T)
  # getter capacity : Int32
  # getter size : Int32
  # getter timeout : Time::Span

  def initialize(@capacity : Int32 = 5, @timeout : Time::Span = 5.seconds, &@generator : -> T)
    @mutex = Core::Mutex.new(:unchecked)
    @condition_variable = Core::ConditionVariable.new
    @size = 0
    @queue = Deque(T).new(@capacity)
  end

  def checkout : T
    @mutex.lock

    if @queue.empty? && @size < @capacity
      @size += 1
      @mutex.unlock
      return @generator.call
    end

    loop do
      if obj = @queue.shift?
        @mutex.unlock
        return obj
      end

      if @condition_variable.wait(pointerof(@mutex), @timeout, relock_on_timeout: false)
        raise TimeoutError.new
      end
    end
  end

  def checkin(obj : T) : Nil
    @mutex.synchronize do
      @queue << obj
      @condition_variable.signal
    end
  end

  def using(& : T -> U) : U forall U
    obj = checkout
    begin
      yield obj
    ensure
      checkin(obj)
    end
  end
end
