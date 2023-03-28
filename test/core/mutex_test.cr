require "../test_helper"
require "../../src/core/mutex"
require "../../src/core/wait_group"

describe Syn::Core::Mutex do
  {% for type in %i[checked unchecked reentrant] %}
    describe {{type}} do
      {% unless type == :reentrant %}
        it "try_lock?" do
          m = Mutex.new({{type}})
          assert m.try_lock?
          refute m.try_lock?
        end
      {% end %}

      it "lock" do
        state = Atomic.new(0)
        m = Mutex.new({{type}})
        m.lock

        ::spawn do
          state.set(1)
          m.lock
          state.set(2)
        end

        eventually { assert_equal 1, state.get }
        m.unlock
        eventually { assert_equal 2, state.get }
      end

      it "unlock" do
        m = Mutex.new({{type}})
        assert m.try_lock?
        m.unlock
        assert m.try_lock?
      end

      {% unless type == :unchecked %}
        it "raises on unlock when not locked" do
          m = Mutex.new({{type}})
          assert_raises(Syn::Error) { m.unlock }
        end

        it "raises when another fiber tries to unlock" do
          m = Mutex.new(:reentrant)
          m.lock

          async do
            assert_raises(Syn::Error) { m.unlock }
          end
        end
      {% end %}

      it "synchronize" do
        m = Mutex.new({{type}})
        counter = 0

        # uses a file to have IO to trigger fiber context switches
        tmp = File.tempfile("syn_mutex", ".txt") do |file|
          100.times do |i|
            ::spawn do
              500.times do
                m.synchronize do
                  file.puts (counter += 1).to_s
                end
              end
            end
          end

          eventually do
            # no races when incrementing counter (parallelism)
            assert_equal 100 * 500, counter
          end
        end

        begin
          # no races when writing to file (concurrency)
          expected = (1..counter).join("\n") + "\n"
          assert_equal expected, File.read(tmp.path)
        ensure
          tmp.try(&.delete)
        end
      end
    end
  {% end %}

  describe "unchecked" do
    it "hangs on deadlock" do
      m = Mutex.new(:unchecked)
      started = locked = false

      fiber = ::spawn do
        started = true

        m.lock
        locked = true

        m.lock # deadlock
        raise "ERROR: unreachable"
      end

      eventually { assert started }
      eventually { assert locked }
      sleep 0.01
    end

    it "unlocks from other fiber" do
      m = Mutex.new(:unchecked)
      m.lock
      async { m.unlock }
    end
  end

  describe "checked" do
    it "raises on deadlock" do
      m = Mutex.new(:checked)
      m.lock
      assert_raises(Syn::Error) { m.lock }
    end
  end

  describe "reentrant" do
    it "try_lock?" do
      m = Mutex.new(:reentrant)
      assert m.try_lock?
      assert m.try_lock?
    end

    it "raises on the 255th re-lock (try_lock?)" do
      m = Mutex.new(:reentrant)
      255.times { m.lock }
      assert_raises(Syn::Error) { m.try_lock? }
    end

    it "re-locks" do
      m = Mutex.new(:reentrant)
      m.lock
      m.lock # nothing raised
    end

    it "raises on the 255th re-lock " do
      m = Mutex.new(:reentrant)
      255.times { m.lock }
      assert_raises(Syn::Error) { m.lock }
    end

    it "must unlock as many times as it try_lock?" do
      m = Mutex.new(:reentrant)
      m.try_lock?
      m.try_lock?
      m.unlock
      m.unlock
      assert_raises(Syn::Error) { m.unlock }
    end

    it "must unlock as many times as it locked" do
      m = Mutex.new(:reentrant)
      m.lock
      m.lock
      m.unlock
      m.unlock
      assert_raises(Syn::Error) { m.unlock }
    end
  end
end
