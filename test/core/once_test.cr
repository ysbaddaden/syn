require "../test_helper"
require "../../src/core/once"

module Syn::Core
  class OnceTest < Minitest::Test
    def test_call
      called = Atomic.new(0)
      done = Atomic.new(0)
      once = Once.new

      100.times do
        ::spawn do
          once.call { called.add(1) }
          done.add(1)
        end
      end

      eventually { assert_equal 100, done.get }
      assert_equal 1, called.get
    end
  end
end
