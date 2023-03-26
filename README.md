# Syn

Synchronization primitives to build concurrent and parallel-safe data structures
in Crystal.

They're structs (not classes) and meant to avoid as many allocations as possible
for the objects to be allocated together right where they're meaningful (inside
the data structures) instead of potentially scattered in the HEAP by the Garbage
Collector.


## Primitives

- `Syn::Flag` is an alternative to `Atomic::Flag` that uses the `:acquire` and
  `:release` memory ordering + fences (memory barriers) to prevent reordering
  by weak CPUs.

- `Syn::Once` ensures that a block of code will only ever run once.

- `Syn::Mutex` a fiber aware regular mutex with support for unchecked, checked
  and reentrant protection.

- `Syn::ConditionVariable` to synchronize the execution of multiple fibers
  through a mutex (a regular condition variable).

- `Syn::RWLock` a multiple readers, mutually exclusive writer lock.

- `Syn::WaitGroup` to wait until a set of fibers have terminated.


## Core

The following structs are very low-level and meant to implement the other `Syn`
primitives, but might still be useful:

- `Syn::Lock` is the interface/mixin used in the different locks in `Syn`.

- `Syn::SpinLock` is a NOOP until multi-threading (MT) is enabled, in which case
  it's meant to very quick lock/unlock to synchronize threads (parallelism).

- `Syn::WaitList` is a singly-linked list of `Fiber`. It assumes that fibers may
  only ever be in a single wait list at all time and will be suspended while
  they're in the list.

  The use of a linked list may not be the best solution (following the list
  means following each `Fiber`) but avoids allocating `Deque` objects (and
  allocating / reallocating their buffer) for each and every wait list.

