require "./test_helper"
require "../src/future"
require "../src/wait_group"

class Syn::FutureTest < Minitest::Test
  def test_set
    value = Future(Int32).new
    assert_equal 123, value.set(123)
  end

  def test_get?
    value = Future(Int32).new
    assert_nil value.get?
    value.set(456)
    assert_equal 456, value.get?
  end

  def test_get
    ready = WaitGroup.new(100)
    counter = Atomic.new(0)

    value = Future(Int32).new
    result = nil

    100.times do
      ::spawn do
        ready.done
        result = value.get
        counter.add(1)
      end
    end

    ::spawn do
      ready.wait
      value.set(789)
    end

    eventually(1.seconds) { assert_equal 789, result }

    assert_equal 789, value.get
  end

  def test_get_timeout
    ready = WaitGroup.new(100)
    counter = Atomic.new(0)

    value = Future(Int32).new
    assert_nil value.get(1.milliseconds)

    result = nil

    100.times do
      ::spawn do
        ready.done
        result = value.get(10.milliseconds)
        counter.add(1)
      end
    end

    ::spawn do
      ready.wait
      value.set(980)
    end

    eventually(1.seconds) { assert_equal 980, result }

    assert_equal 980, value.get(1.milliseconds)
  end
end
