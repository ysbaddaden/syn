module Syn
  # Raised when an error occurs when locking or unlocking `Mutex` or
  # `Core::Mutex`.
  class Error < Exception
  end

  # Raised when a high level structure (e.g. Pool) reaches a timeout.
  class TimeoutError < Exception
  end
end
