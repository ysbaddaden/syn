require "./core/wait_group"

class Syn::WaitGroup
  @wg : Core::WaitGroup

  def initialize(counter : Int32 = 0)
    @wg = Core::WaitGroup.new(counter)
  end

  def add(count : Int) : Nil
    @wg.add(count)
  end

  def done : Nil
    @wg.done
  end

  def wait : Nil
    @wg.wait
  end

  def wait(timeout : Time::Span) : Bool
    @wg.wait(timeout)
  end
end
