# StructuredOperationsKit

Integration of classic Operations and modern Swift Concurrency with Structured Concurrency. When a task or operation is canceled the other should as well automatically. It is implemented by having a `ParentOperation` which has a nested actor type named `Child` which provides the async behavior.

This sample code code is an attempt to make class Operations coordatinate with Task cancellations.

## Why

Operations are still very useful. They were introduced with iOS 2.0 when the developer API was first released outside of Apple when iPhones were single core devices. Dispatch was not released until iOS 4.0 when iPhones were built with 2 cores, making thread-safety a higher priority. Now Apple hardware across each of the supported platforms can include many cores which increases the chances of race conditions across threads.

With the introduction of Apple Silicon and Swift Concurrency it is now possible to define a Task which can have many child tasks. Canceling a parent task will cancel all child tasks. If the entry point to starting the work is an Operation and it is canceled it should cause any Task running within the Operation to be canceled. And if the primary Task within an Operation is cancelled it should also state the state of the Operation to cancelled.

One key benefit of Operations is the ability to limit concurrent operations without blocking. Adding Operations to an OperationQueue which only allows for a single Operation to run at a time effectively creates serial behavior without blocking. In contrast, a serial DispatchQueue will line up DispatchWorkItems on a `sync` call which can lead to hangs caused by thread exhaustion. When an Operation is pending it is not blocking a thread. It will stay pending until it can be started and not contributed to hangs or thread exhaustion.
