require "./core/condition_variable"

class Syn::ConditionVariable
  @condition_variable : Core::ConditionVariable

  def initialize
    @condition_variable = Core::ConditionVariable.new
  end

  def wait(mutex : Mutex) : Nil
    @condition_variable.wait(pointerof(mutex.@mutex))
  end

  def wait(mutex : Mutex, timeout : Time::Span) : Bool
    @condition_variable.wait(pointerof(mutex.@mutex), timeout)
  end

  def signal : Nil
    @condition_variable.signal
  end

  def broadcast : Nil
    @condition_variable.broadcast
  end
end
