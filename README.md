# Syn

Synchronization primitives to build concurrent and parallel-safe data structures
in Crystal.


## `Syn` namespace

High level abstractions to the underlying Syn::Core structs or completely new
types built on top of the Syn::Core structs. They're implemented as classes, and
thus allocated in the HEAP and always passed by reference. I.e. they're safe to
use in any context.

### `Syn::Mutex`

A mutually exclusive lock. Only allows a single fiber from accessing a block of
code and shared data at once, and blocks all the other fibers that may want to
read or write the shared data.

Supports multiple types of protections:

- `:checked` (default): attempts to re-lock the mutex from the same fiber or to
  unlock from another fiber than the one that locked it will raise an exception
  (`Syn::Error`) as they are programming errors.

- `:unchecked`: doesn't check for anything: attempts to re-lock will cause a
  deadlock situation and any fiber is allowed to unlock the mutex. It doesn't
  bring much benefit over `:checked` (maybe a very limited performance gain).

- `:reentrant`: similar to checked but instead of raising it remembers how many
  times the lock has been acquired and the exact same amount of unlock must
  happen to properly unlock the mutex. Trying to unlock from another fiber will
  still raise.

Example:

```crystal
mutex = Syn::Mutex.new
results = [] of Int32

10.times do
  spawn do
    result = calculate_something
    mutex.synchronize { results << result }
  end
end
```

### `Syn::Condition`

Both a Mutex _and_ a Condition Variable in a single type.

### `Syn::WaitGroup`

Wait until a number of fibers have terminated. The number of fibers to wait for
can be incremented at any time.

Example:

```crystal
wg = Syn::WaitGroup.new(100)

100.times do
  spawn do
    if rand(0..1) == 1
      wg.add(1)
      spawn { wg.done }
    end

    wg.done
  end
end

# block until *all* fibers are done
wg.wait
```

### `Syn::RWLock`

A multiple readers, mutually exclusive writer lock. Allows multiple fibers to
have read access to a the same block of code and shared data, but only allow a
single writer to have exclusive read and write access to the shared data.

This type is biased upon reads (many fibers can read) while writing will still
block everything (only one fiber can write). It should be preferred over a mutex
when writes happen sporadically.


## `Syn::Core` namespace

Syn::Core are low level structs that implement the actual synchronization logic.

The advantage of structs is that you can embed the primitives right into the
objects that need them and have them allocated next to each other when they need
to interact together. It means less GC allocations, and less potentially
scattered memory accesses. The disadvantage is that they're structs and thus
unsafe to pass around (structs are passed by value, i.e. duplicated), and you
must make sure to always pass them by reference (i.e. pointers) or to always
access them directly as pure local or instance variables.

- `Syn::Core::Flag` is an alternative to `Atomic::Flag` that uses the `:acquire`
  and `:release` memory ordering + fences (memory barriers) to prevent code
  reordering at runtime by weak CPUs.

- `Syn::Core::Once` ensures that a block of code will only ever run once.

- `Syn::Core::Mutex` a fiber aware regular mutex with support for unchecked,
  checked and reentrant protection.

- `Syn::Core::ConditionVariable` to synchronize the execution of multiple fibers
  through a mutex (a regular condition variable).

- `Syn::Core::WaitGroup` to wait until a set of fibers have terminated.

The following types are the fundational types of the above core types:

- `Syn::Core::WaitList` is a singly-linked list of `Fiber`. It assumes that
  fibers may only ever be in a single wait list at all time and will be
  suspended while they're in the list.

  The use of a linked list may not be the best solution (following the list
  means following each `Fiber` which may trash CPU caches) but it avoids
  allocating `Deque` objects (+ their buffers) for each and every wait list...

- `Syn::Core::SpinLock` is a NOOP until multi-threading (MT) is enabled, in
  which case it's meant for quick lock/unlock to synchronize threads together.

## License

Distributed under the Apache-2.0 license.
