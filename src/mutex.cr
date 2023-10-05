require "./core/mutex"

# A Fiber aware, mutually exclusive lock.
#
# Prevents two or more fibers to access the same non concurrent piece of code
# (e.g. mutating a shared object) at the same time.
#
# There are three types of mutexes.
#
# - **Checked** mutexes memorize the fiber that locked the mutex; trying to
#   lock the mutex twice from the same fiber will raise an exception; trying
#   to unlock from another mutex will also raise an exception.
#
#   Checked mutexes are the default type, and the only safe type of mutex.
#
# - **Unchecked** mutexes don't check for errors; trying to lock twice from
#   the same fiber will deadlock; any fiber is allowed to unlock the mutex.
#
#   If the mutex is to protect a shared data structure, and its usage is
#   restricted to an object's internals, you may consider unchecked mutexes
#   for a limited performance gain.
#
# - **Reentrant** mutexes also memorize the fiber that locked the mutex; the
#   same fiber is allowed to re-lock the mutex up to 255 times (afterwards an
#   exception will be raised). Only the fiber that locked the mutex is allowed
#   to unlock the mutex, but it must unlock it has many times as it previously
#   locked it to actually unlock it.
#
#   There are probably valid use cases for reentrant mutexes, but ideally you
#   shouldn't never have to use them (there are better synchronization concepts
#   for complex use cases). Yet, they might be useful temporary as a quick
#   workaround to deadlocks?
#
# This is a smaller and fully contained alternative to the `::Mutex` class in
# stdlib that doesn't allocate extraneous objects. It also exposes the quick
# `#try_lock?` that won't block.
#
# TODO: check whether the owning fiber is still alive or not (i.e. EOWNERDEAD)
class Syn::Mutex
  def initialize(type : Core::Mutex::Type = :checked)
    @mutex = Core::Mutex.new(type)
  end

  # Returns true if the lock could be acquired, otherwise immediately returns
  # false without blocking.
  #
  # Merely returns false whenever the lock if already held. Doesn't check if the
  # current fiber currently holds the lock, doesn't raise and also doesn't
  # increment the counter for reentrant mutexes (unless it's the initial lock).
  def try_lock? : Bool
    @mutex.try_lock?
  end

  # Acquires the lock, suspending the current fiber until the lock can be
  # acquired.
  #
  # If the mutex is unchecked, trying to re-lock while the current fiber is
  # already holding the lock will result in a deadlock. If checked it will raise
  # an `Error`. If reentrant, the counter will be incremented and the method
  # will return.
  def lock : Nil
    @mutex.lock
  end

  # Identical to `#lock` but aborts if the lock couldn't be acquired until
  # timeout is reached, in which case it returns false (failed to acquire lock).
  # Returns true if the lock was acquired.
  @[Experimental("The timeout feature is experimental.")]
  def lock(timeout : Time::Span) : Bool
    @mutex.lock(timeout)
  end

  # Releases the lock.
  #
  # If unchecked, any fiber can unlock the mutex and the mutex doesn't even need
  # to be locked.
  #
  # If checked or reentrant, the mutex must have been locked and only the fiber
  # holding the lock is allowed otherwise `Error` exceptions will be raised. If
  # reentrant the counter will be decremented and the lock only released when
  # the counter reaches zero (i.e. you must call `#unlock` as many times as
  # `#lock` was called.
  def unlock : Nil
    @mutex.unlock
  end

  # Acquires the lock, yields, then releases the lock, even if the block raised
  # an exception.
  def synchronize(& : -> U) : U forall U
    @mutex.synchronize { yield }
  end

  # Similar to `#synchronize` but aborts if the lock couldn't be acquired until
  # timeout is reached, in which case it returns false.
  #
  # NOTE: unlike `#synchronize` it doesn't return the block's value, but whether
  #       timeout was reached!
  @[Experimental("The timeout feature is experimental.")]
  def synchronize(timeout : Time::Span, & : ->) : Bool
    @mutex.synchronize(timeout) { yield }
  end
end
