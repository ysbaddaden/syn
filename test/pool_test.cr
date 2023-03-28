require "./test_helper"
require "../src/pool"
require "../src/wait_group"

class Syn::PoolTest < Minitest::Test
  class Foo
  end

  def test_doesnt_start_any_by_default
    counter = Atomic.new(0)
    pool = Pool(Foo).new do
      counter.add(1)
      Foo.new
    end
    assert_equal 0, counter.get
  end

  def test_starts_one_on_demand
    counter = Atomic.new(0)
    pool = Pool(Foo).new do
      counter.add(1)
      Foo.new
    end

    foo = pool.checkout
    assert_instance_of Foo, foo
    assert_equal 1, counter.get
    pool.checkin(foo)

    5.times do
      foo2 = pool.checkout
      assert_same foo, foo2, "Expected pool to keep returning the same object"
      assert_equal 1, counter.get
      pool.checkin(foo2)
    end
  end

  def test_starts_more_when_needed
    counter = Atomic.new(0)
    pool = Pool(Foo).new do
      counter.add(1)
      Foo.new
    end

    foo1 = pool.checkout
    assert_equal 1, counter.get

    foo2 = pool.checkout
    assert_equal 2, counter.get

    pool.checkin(foo1)
    assert_same foo1, pool.checkout

    pool.checkin(foo2)
    assert_same foo2, pool.checkout
  end

  def test_checkout_eventually_timeouts
    counter = Atomic.new(0)
    pool = Pool(Foo).new(capacity: 2, timeout: 1.milliseconds) do
      counter.add(1)
      Foo.new
    end

    assert_instance_of Foo, pool.checkout
    assert_instance_of Foo, pool.checkout

    done = false
    exception = nil

    ::spawn do
      exception = assert_raises(Syn::TimeoutError) { pool.checkout }
      done = true
    end

    eventually(1.seconds) do
      assert done, "expected fiber to have terminated"
    end
    assert exception, "expected checkout to have raised an exception"
  end

  def test_checkout_starts_up_to_capacity
    counter = Atomic.new(0)
    wg = WaitGroup.new(10)

    pool = Pool.new(capacity: 3) do
      counter.add(1)
      Foo.new
    end

    10.times do
      ::spawn do
        foo = pool.checkout
        sleep 0.001
        pool.checkin(foo)

        wg.done
      end
    end

    wg.wait(2.seconds)
    assert_equal 3, counter.get
  end
end
