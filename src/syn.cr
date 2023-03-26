require "./*"

module Syn
  # Returns `true` if the timeout was reached, and returns `false` if the fiber
  # was manually resumed earlier.
  #
  # FIXME: poor man's detection of early resume vs manual fiber resume (may
  #        return false positive if the scheduler takes too much time to resume
  #        the reenqueued fiber).
  #
  # TODO: consider returning an Enum (?)
  def self.sleep(timeout : Time::Span) : Bool
    Time.measure { ::sleep(timeout) } > timeout
  end
end
