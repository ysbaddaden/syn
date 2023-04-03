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

  def test_get_timeout_returns_nil
    value = Future(Int32).new
    assert_nil value.get(1.millisecond)
  end

  def test_get_timeout_returns_value
    value = Future(Int32).new
    value.set(12345)
    assert_equal 12345, value.get(1.millisecond)
  end

  def test_get_timeout_eventually_returns_value
    ready = WaitGroup.new(1)
    done = false

    value = Future(Int32).new
    result = nil

    ::spawn do
      ready.done
      result = value.get(1.second)
      done = true
    end

    ::spawn do
      ready.wait
      value.set(980)
    end

    eventually { assert done }
    assert_equal 980, result
  end

  def test_get_timeout_concurrency
    ready = WaitGroup.new(100)
    wg = WaitGroup.new(100)

    value = Future(Int32).new
    counter = Atomic.new(0)

    100.times do
      ::spawn do
        ready.done
        assert rs = value.get(1.second)
        counter.add(rs.not_nil!)
        wg.done
      end
    end

    ::spawn do
      ready.wait
      value.set(980)
    end

    wg.wait
    eventually { assert_equal 98_000, counter.get }
  end
end
