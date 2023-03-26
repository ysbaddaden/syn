require "./test_helper"
require "../src/mutex"
require "../src/condition_variable"

module Syn
  class ConditionVariableTest < Minitest::Test
    def test_signal
      m = Mutex.new(:unchecked)
      c = ConditionVariable.new
      done = waiting = 0

      100.times do
        ::spawn do
          m.synchronize do
            waiting += 1
            c.wait(pointerof(m))
            done += 1
          end
        end
      end
      eventually { assert_equal 100, waiting }

      # resume fibers one by one
      0.upto(99) do |i|
        eventually { assert_equal i, done }
        c.signal
        ::sleep(0)
      end

      eventually { assert_equal 100, done }
    end

    def test_broadcast
      m = Mutex.new(:unchecked)
      c = ConditionVariable.new
      done = waiting = 0

      100.times do
        ::spawn do
          m.synchronize do
            waiting += 1
            c.wait(pointerof(m))
            done += 1
          end
        end
      end
      eventually { assert_equal 100, waiting }
      assert_equal 0, done

      # resume all fibers at once
      c.broadcast
      eventually { assert_equal 100, done }
    end

    # TODO: play ping pong between producer & consumer
    # FIXME: producer must wait for consumer to be ready (MT: random failures)
    def test_producer_consumer
      m = Mutex.new(:unchecked)
      c = ConditionVariable.new

      state = -1
      ready = false

      ::spawn(name: "consumer") do
        m.synchronize do
          ready = true

          # loop do
            c.wait(pointerof(m))
            assert_equal 1, state

            state = 2
            # c.signal
          # end
        end
      end

      ::spawn(name: "producer") do
        eventually { assert ready, "expected consumer to eventually be ready" }

        m.synchronize { state = 1 }
        # FIXME: signal may be sent _before_ the other fiber is waiting
        c.signal
      end

      # m.synchronize do
      #   c.wait(pointerof(m))
      # end
      # assert_equal 2, state

      eventually { assert_equal 2, state }
    end
  end
end
