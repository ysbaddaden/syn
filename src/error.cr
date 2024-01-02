module Syn
  # Raised when an error occurs when locking or unlocking `Mutex` or
  # `Core::Mutex`.
  class Error < Exception
  end

  # Raised when a high level structure (e.g. Pool) reaches a timeout.
  class TimeoutError < Exception
  end

  # Raised when a future failed without an explicit `Exception`.
  class FailedError < Exception
  end

  # Raised when trying to resolve a future (set value or error) that has already
  # been resolved.
  class AlreadyResolved < Exception
  end
end
