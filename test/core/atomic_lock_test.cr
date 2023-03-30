require "../test_helper"
require "../../src/core/atomic_lock"

module Syn::Core
  class AtomicLockTest < Minitest::Test
    def test_acquire_and_release
      done = Atomic.new(0)
      counter = 0

      lock = AtomicLock.new

      100.times do
        ::spawn do
          1000.times do
            until lock.acquire?
              sleep(0)
            end

            counter += 1
            lock.release
          end

          done.add(1)
        end
      end

      eventually { assert_equal 100, done.get }
      assert_equal 100 * 1000, counter
    end
  end
end
