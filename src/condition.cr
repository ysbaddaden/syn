require "./core/mutex"
require "./core/condition_variable"

class Syn::Condition
  @mutex : Core::Mutex
  @condition_variable : Core::ConditionVariable

  def initialize(type : Core::Mutex::Type = :checked)
    @mutex = Core::Mutex.new(type)
    @condition_variable = Core::ConditionVariable.new
  end

  def try_lock? : Bool
    @mutex.try_lock?
  end

  def lock : Nil
    @mutex.lock
  end

  def lock(timeout : Time::Span) : Bool
    @mutex.lock(timeout)
  end

  def unlock : Nil
    @mutex.unlock
  end

  def synchronize(& : -> U) : U forall U
    @mutex.synchronize { yield }
  end

  def synchronize(timeout : Time::Span, & : ->) : Bool
    @mutex.synchronize(timeout) { yield }
  end

  def wait : Nil
    @condition_variable.wait(pointerof(@mutex))
  end

  def wait(timeout : Time::Span) : Bool
    @condition_variable.wait(pointerof(@mutex), timeout)
  end

  def signal : Nil
    @condition_variable.signal
  end

  def broadcast : Nil
    @condition_variable.broadcast
  end
end
