require "./test_helper"
require "../src/future"
require "../src/wait_group"

class Syn::FutureTest < Minitest::Test
  def test_set
    value = Future(Int32).new
    assert_equal 123, value.set(123)
  end

  def test_fail
    value = Future(Int32).new
    value.fail(Exception.new)
  end

  def test_already_set
    value = Future(Int32).new
    value.set(123)

    assert_raises(AlreadyResolved) { value.set(456) }
    assert_raises(AlreadyResolved) { value.fail(Exception.new) }
    assert_equal 123, value.get?
  end

  def test_already_failed
    value = Future(Int32).new
    exception = Exception.new
    value.fail(exception)

    assert_raises(AlreadyResolved) { value.fail(Exception.new) }
    assert_raises(AlreadyResolved) { value.set(123) }
    raised_exception = assert_raises(Exception) { value.get }
    assert_same exception, raised_exception
  end

  def test_get?
    value = Future(Int32).new
    assert_nil value.get?
    value.set(456)
    assert_equal 456, value.get?
  end

  def test_failed_get?
    value = Future(Int32).new
    assert_nil value.get?
    value.fail
    assert_raises(FailedError) { value.get? }

    value = Future(Int32).new
    assert_nil value.get?
    value.fail(Exception.new("lorem ipsum"))
    ex = assert_raises(Exception) { value.get? }
    assert_equal "lorem ipsum", ex.message
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

  def test_failed_get
    ready = WaitGroup.new(1)
    value = Future(Int32).new
    result = nil

    ::spawn do
      ready.done
      result = assert_raises(FailedError) { value.get }
    end

    ::spawn do
      ready.wait
      value.fail
    end

    eventually(1.seconds) { assert_instance_of FailedError, result }

    assert_raises(FailedError) { value.get }
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

  def test_failed_get_timeout_returns_value
    value = Future(Int32).new
    value.fail
    assert_raises(FailedError) { value.get(1.millisecond) }
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

  def test_get_timeout_eventually_fails
    ready = WaitGroup.new(1)
    done = false

    value = Future(Int32).new
    result = nil

    ::spawn do
      ready.done
      result = assert_raises(FailedError) { value.get(1.second) }
      done = true
    end

    ::spawn do
      ready.wait
      value.fail
    end

    eventually { assert done }
    assert_instance_of FailedError, result
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

  def test_failed_get_timeout_concurrency
    ready = WaitGroup.new(100)
    wg = WaitGroup.new(100)

    failed = Atomic(Int32).new(0)
    value = Future(Int32).new

    100.times do
      ::spawn do
        ready.done
        assert_raises(FailedError) { value.get(1.second) }
        failed.add(1)
        wg.done
      end
    end

    ::spawn do
      ready.wait
      value.fail
    end

    wg.wait
    assert_equal 100, failed.get
  end
end
