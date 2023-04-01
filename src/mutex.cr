require "./core/mutex"

class Syn::Mutex
  @mutex : Core::Mutex

  def initialize(type : Core::Mutex::Type = :checked)
    @mutex = Core::Mutex.new(type)
  end

  def try_lock? : Bool
    @mutex.try_lock?
  end

  def lock : Nil
    @mutex.lock
  end

  # NOTE: the timeout feature is experimental.
  def lock(timeout : Time::Span) : Bool
    @mutex.lock(timeout)
  end

  def unlock : Nil
    @mutex.unlock
  end

  def synchronize(& : -> U) : U forall U
    @mutex.synchronize { yield }
  end

  # NOTE: the timeout feature is experimental.
  def synchronize(timeout : Time::Span, & : ->) : Bool
    @mutex.synchronize(timeout) { yield }
  end
end
