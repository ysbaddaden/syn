require "./test_helper"
require "../src/wait_group"

module Syn
  class WaitGroupTest < Minitest::Test
    def test_lifetime
      wg = WaitGroup.new
      wg.add(1000)
      counter = Atomic(Int32).new(0)

      1000.times do
        ::spawn do
          wg.done
          counter.add(1)
        end
      end

      wg.wait
      assert_equal 1000, counter.get
    end
  end
end
