require "./test_helper"
require "../src/rw_lock"
require "../src/core/wait_group"

module Syn
  class RWLockTest < Minitest::Test
    def test_lifetime
      rw = RWLock.new
      wg = Core::WaitGroup.new(9)

      ary = [] of Int32
      counter = Atomic(Int64).new(0)

      # readers can run concurrently, but are mutually exclusive to writers (the
      # array can be safely read from):

      10.times do
        ::spawn(name: "reader") do
          100.times do
            rw.lock_read do
              ary.each { counter.add(1) }
            end
            ::sleep(0)
          end
        end
      end

      # writers are mutually exclusive: they can safely modify the array

      5.times do
        ::spawn(name: "writer: increment") do
          100.times do
            rw.lock_write { 100.times { ary << ary.size } }
            ::sleep(0)
          end
          wg.done
        end
      end

      4.times do
        ::spawn(name: "writer: decrement") do
          100.times do
            rw.lock_write { 100.times { ary.pop? } }
            ::sleep(0)
          end
          wg.done
        end
      end

      wg.wait

      assert_equal (0..(ary.size - 1)).to_a, ary
      assert counter.lazy_get > 0
    end

    def test_lock_unlock
      rw = RWLock.new

      done = false

      rw.lock_read
      rw.lock_read

      ::spawn do
        rw.lock_write
        done = true
      end

      sleep(0.1)
      refute done

      rw.unlock_read
      sleep(0.1)
      refute done

      rw.unlock_read
      sleep(0.1)
      assert done
    end

    def test_cant_lock_read_while_locked_for_write
      rw = RWLock.new
      rw.lock_write

      done = false

      ::spawn do
        rw.lock_read
        done = true
      end

      sleep(0.1)
      refute done

      rw.unlock_write
      sleep(0.1)
      assert done
    end
  end
end
