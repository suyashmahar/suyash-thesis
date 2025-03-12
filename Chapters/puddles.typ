#import "../macros.typ": * 

// Persistent Memory (PM) provides byte-addressability and large capacity, making it ideal for memory-hungry applications like in-memory databases, graph workloads, and big-data applications. Over the past decade, researchers have proposed a host of systems that manage many of PM's idiosyncrasies and the programming challenges it presents (#emph[e.g.];, persistent memory allocation and crash recovery).

// However, 
Existing PM programming systems are built on a patchwork of modifications to the memory-mapped file interface and thus make several compromises in how persistent data is accessed. These systems use custom pointer formats, handle logging through ad-hoc mechanisms, and implement recovery using diverse but incompatible logging and transactional semantics.

For example, opening multiple copies of a pool that resides at a fixed address would result in address conflicts. For another, using non-native (#emph[i.e.];, "smart" or "fat" ) pointers avoids the need for fixed addresses but adds performance overhead to common-case accesses, makes persistent data unreadable by non--PM-aware code, leaves software tools (#emph[e.g.];, debuggers) unable to interpret that data, and locks-in the PM data to a particular PM library. Further, current implementations of fat-pointers do not allow multiple copies of PM data to be mapped simultaneously unless the PM library first translates all pointers in one of the copies. Finally, enforcing crash consistency in the application requires that after a crash, 1) the application is still available, 2) the application still has write permissions for the data (even if the application only wants to read it) #Green[to ensure that it can recover from any incomplete transactions], and 3) the system knows which application was running at the time of the crash #Green[(to ensure that the recovery application can parse the recovery logs)]---none of which are true in general.

Today's PM programming libraries thus leave the critical issue of data integrity in the hands of the programmer and system administrators rather than robustly ensuring those properties at the system level. Further, existing PM programming libraries restrict basic operations like opening cloned copies of PM data simultaneously, reading PM data without write access, or using legacy pointer-based tools to access PM data. A storage system with these characteristics represents a step back in safety and data integrity compared to the state-of-the-art persistent storage systems---namely filesystems.

In this chapter, we show that the design of existing PM libraries results in PM programming models that severely limit programming flexibility and introduce additional unnatural constraints and performance problems. 
To solve these problems, we propose a new persistent memory programming library, #emph[Puddles];. Puddles solve these problems while preserving the speed and flexibility that the existing PM programming interface provides. Puddles provide the following properties:

1. #emph[Application-independent crash-recovery];: PM recovery after a crash in Puddles completes before #emph[any] application accesses the data. // Recovery succeeds even if the application writing data at the time of the crash is absent after restart, no longer has the write permissions, or was just one of the multiple applications updating the data at the time of the crash.
  Recovery succeeds even if the application writing data at the time of the crash is absent after restart or no longer has the write permissions.

2. #emph[Native pointers for PM data];: Puddles use native pointers and, thus, allow code written with other PM libraries or non-PM-aware code (#emph[e.g.], compilers and debuggers) to read and reason about it. Pointers are a fundamental and universal tool for in-memory data structure construction. // Changing their implementation for PM adds runtime overhead of translation, requires specialized code to read PM data, and stymies software engineering tools (#emph[e.g.];, compilers and debuggers do not understand custom pointer formats used by PM libraries).

3. #emph[Relocatability];: Puddles can transparently relocate data to avoid any address conflicts and thereby enable sharing and relocation of PM data between machines.
~

Puddles is the first PM programming system that provides application-independent recovery on a crash and supports both native pointers and relocatability while providing a traditional transactional interface. Designing Puddles, however, is challenging as native pointers, relocatability, and mappable PM data are properties that are at odds with each other. For example, native-pointers have traditionally prevented relocatable PM data, and non-mappable data like JSON does not support pointers.

To resolve these conflicts, the Puddles system divides PM pools into #emph[puddles];. Each puddle is a small, modular region of persistent memory (several MiBs) that the Puddles library can map into an application's address space. Puddles provide non-PM-aware applications access to PM data by allowing programs to use native pointers. To support sharing puddles between processes and shipping puddles between machines, puddles are relocatable---they can be mapped to arbitrary virtual addresses to resolve address conflicts. To support relocation, puddles are structured so that all pointers are easy to find and translate while, dividing pools into puddles allows translation to occur incrementally and on demand. The Puddles library works in tandem with a privileged system service that allocates, manages, and protects the puddles.

To ensure that puddles are always consistent after a crash, puddle programs register log regions with the system service and store the logs in those regions in a format the service can safely apply after a crash. After a crash, the system applies logs before #emph[any] application can access the PM data. Puddles' flexible log format can accommodate a wide range of logging styles (undo, redo, and hybrid). While applications can access individual puddles, Puddles supports composing them into seamless collections that resemble traditional PM pools, allowing applications to allocate data structures that span multiple puddles.

We compare Puddles against PMDK and other PM programming libraries using several workloads. Puddles implementation is always as fast as and up to 1.34$times$ faster than PMDK across the YCSB workloads. Puddles' use of native virtual pointers allows them to significantly outperform PMDK in pointer-chasing benchmarks. Against Romulus, a state-of-the-art persistent memory programming library that uses DRAM+PMEM, Puddles, a PMEM-only programming library is between 36% slower to being equally fast across the YCSB workloads.

// For linked-list traversal and B-tree search workloads, compared to PMDK, Puddles implementation is 13.4$times$ and 3.1$times$ faster, respectively. Moreover, support for relocatability allows Puddles to perform data aggregation on copies of PM data without expensive serialization or reallocation, resulting in a 4.7$times$ speedup over PMDK.

== Limitations of Current PM Systems
<sec:pm-programming-challenges>

#let box90(content) = table.cell({
    set par(leading: 0.5em)
    rotate(-90deg, reflow: true)[
      
      #content
      
    ]
  }
)

#place(top, float: true, [
  // #show table.cell.where(y: 0): set text(size: 0.8em, weight: "bold")
  #show table.cell.where(y: 0): strong
  #figure(
    caption: [Puddles vs. recent PM programming libraries.],
    table(
        columns: (auto, auto, auto, auto, auto, auto, auto),
        align: horizon,
        table.header(
          box90([System]), 
          box90([Transactional \ Support]), 
          box90([Native \ Pointers]), 
          box90([Application \ Independent \ Recovery]), 
          box90([Object \ Relocatability]), 
          box90([Region \ Relocatability]), 
          box90([Cross-pool \ Transaction])

        ),
        [PMDK~@pmdk], yes, no, no, no, yes, no,
        [TwizzlerOS~@bittman2020twizzler], yes, no, no, yes, yes, no,
        [Mnemosyne~@mnemosyne], yes, yes, no, no, no, yes,
        [NV-Heaps~@nvheaps], yes, no, no, no, yes, no,
        [Corundum~@corundum], yes, no, no, no, yes, no,
        [Atlas~@atlas], yes, yes, no, no, yes, no,
        [Clobber-NVM~@clobbernvm], yes, yes, no, no, yes, no,
        [Puddles], yes_heavy, yes_heavy, yes_heavy, yes_heavy, yes_heavy, yes_heavy
    )
  )<tab:related-pm-libraries>~
  
])

Current persistent memory programs suffer from a host of problems that limit their usability, reliability, and flexibility in ways that would be unthinkable for more mature data storage systems (e.g., file systems, object stores, or databases). In particular, they rely on the program running at the time of the crash for recovery, use proprietary pointers that lock data into a single application or library, and place limits on the combination of pools (i.e., files) an application can have open at one time.

A novel file system with similar properties would garner little notice as a serious storage mechanism, and we should hold PM systems to a similar standard.

To understand the limitations and fragmented feature space of PM libraries, @tab:related-pm-libraries compares several PM programming libraries across multiple axes. Puddles is the only PM programming library that supports features like application-independent recovery, object relocatability (moving individual objects in a process's address space), region relocatability (moving groups of objects), and the ability to modify any global PM data in a transaction, features that users expect from a mature storage system.

The rest of the section examines problems that are endemic to existing PM programming solutions. First, we look closely at these problems that plague current PM programming solutions and then understand how they hold back PM applications.

=== PM Crash Recovery is Brittle and Unreliable
<pm-crash-recovery-is-brittle-and-unreliable>

When an application crashes, current PM programming libraries require the user to restart the application that was running at crash time to make the data consistent. This design decision breaks the common understanding of data recovery.

For example, if a PDF editor crashes while editing a PDF file stored in a conventional file system, the user can reopen the file with a different PDF editor and continue their work. With current PM programming libraries, this is not possible. The user must re-run the same program again, or the data may be inconsistent.

This problem may seem benign, but this crash-consistency model relies on several assumptions that do not hold in general---like the availability of the original writer application and need for write access after a crash. The net result is an ad hoc approach to ensuring data consistency that is far removed from what state-of-the-art file systems provide.

Indeed, ensuring recovery may not be possible at all in some circumstances.

For example, the user might lose write access to the data if their credentials have expired, preventing them from opening the file to perform recovery. Alternatively, the original application may no longer be available either because the licenses have expired, OS and PM library updates have changed the transactional semantics, or if the file is restored from a backup on another system or the physical storage media is moved to a new system. If any of these assumptions fail, recovery will be impossible, and the data will be left in an inconsistent state.

PMDK, the most widely used PM library, illustrates how a lack of permissions can prevent recovery. In PMDK, recovery is triggered only after the application restarts and reads the same PM data; otherwise, the data is inconsistent. When the inconsistent data is eventually read, PMDK looks for any incomplete transactions to recover the PM data to a consistent state. PMDK thus needs both read and write permissions to the data before the application can read it.


=== PM Pointers are Restrictive and Inflexible
<pm-pointers-are-restrictive-and-inflexible>

#place(top, float: true, [#figure([#block[
  #box(image("../Figures/Puddles/ptr-chasing-benchmarks.svg"))
  ]],
  caption: [
    Linkedlist and binary tree creation and traversal microbenchmarks, showing overhead of fat pointers vs.~native pointers. Single-threaded workload. Linked list's length: $2^16$, and tree height: $16$
  ]
)<fig:fat-ptr-overhead>~])

Persistent memory enables pointer-rich persistent data, but existing PM systems offer programmers two non-optimal choices: (a) use fat-pointers (base+offset) or self-relative pointers and add overhead to pointer dereference, or (b) use native pointers and abandon relocatability.

Because fat pointers need to be translated to the native format on every dereference, they suffer from a significant performance overhead. Further, the large size of these pointers (in most cases, 128 bits) results in a worse cache locality. @fig:fat-ptr-overhead shows the overhead of fat pointers over native pointers when creating and traversing a linked list and a binary tree. Fat pointers show up to 16% runtime overhead and result in an 18% higher L1 cache miss rate for the binary search tree microbenchmark.

Finally, using a non-native format for pointers makes them opaque and uninterpretable to existing tools like compilers and debuggers.

=== PM Data is Hard to Relocate and Clone
<pm-data-is-hard-to-relocate-and-clone>

Regardless of the pointer format choice, PM data is hard to relocate. Consequently, with existing PM systems, users cannot create copies of PM data and open them simultaneously, as the copies would either map to the same address (with native pointers), or have the same UUID (with fat pointers). Likewise, while some pointer schemes (e.g., self-relative~@nvheaps) allow for relocation, they require relocating the entire pool at once and do not support pointers between pools.

When using native pointers, cloned PM data contains conflicting pointers, and the library has no way of rewriting them as the application does not know where the pointers are. A similar problem exists with fat pointers: the application would need to rewrite the base address of each pointer which is impossible in current PM programming systems.

For example, the most widely used PM library, PMDK~@pmdk, identifies each "pool" of PM with a UUID and embeds that UUID in its fat pointers. This design requires a specialized tool to copy pools because the copy needs a new UUID and all the pointers it contains need updating. PMDK thus prevents users from opening multiple copies of a pool by checking if the UUID of the pool was already registered when it was first opened. Further, the design also disallows pointers between pools.

With persistent memory becoming more ubiquitous with the emergence of CXL-based memory semantic SSDs~@samsung-ssd and ReRAM-based SoCs~@reram-soc, beyond just Intel's Optane, the challenges of current persistent memory programming remain present.


== Overview
<sec:overview>

The #emph[Puddles] library is a new persistent memory library to access PM data that supports application-independent recovery, and implements cheap, transparent relocatability, all while supporting native pointers. To provide these features, Puddles implement system-supported logging and recovery, a shared, machine-local PM address space for PM data, and transparent pointer rewriting to resolve address space conflicts. In Puddles, every application that needs to access its data does so by mapping a puddle in its virtual address space.

=== Pools and Puddles
<sec:puddles-and-pools>

Pools in the Puddle system are named collections of persistent memory regions (i.e., puddles) that allow programmers to allocate and deallocate objects. Pools automatically acquire new memory for object allocation and logging and free any unused memory to the system.

Pools are made of puddles that are mappable units of persistent memory in the Puddle system. While smaller than a pool, puddles can span multiple system pages to accommodate large data structures. The size of a puddle does not change, but pools can grow and shrink with the addition or removal of puddles. Finally, `Libpuddles` supports sharing of pools across machines in its in-memory representation enabling sharing PM data with no serialization.

=== Puddles Implementation
<puddles-implementation>

The Puddle system consists of three major system components (@fig:puddles-arch) that work together to provide application support for mapping and managing puddles.

#place(top, float: true, [#figure([#block[
  #box(image("../Figures/Puddles/architecture.svg"))
  ]],
  caption: [
    The Puddles system includes `Puddled` for system-supported persistence, `Libpuddles`, and `Libtx` for a simple programming interface on top of `Puddled`'s primitives.
  ]
)
<fig:puddles-arch>~])

+ #emph[`Puddled`] is the privileged daemon process that manages access to all the puddles in a machine. `Puddled` implements access control and provides APIs for system-supported recovery and relocating persistent memory data.

+ #emph[`Libpuddles`] talks to `Puddled` and provides functions to allocate and manage puddles and pools.

+ #emph[`Libtx`] is a library that builds on `Libpuddles` to provide failure-atomic transactions that resemble the familiar PMDK transactions.

Together, `Libpuddles` and `Libtx` provide a PMDK-like interface allowing the application to open pools, allocate objects, and execute transactions without managing or caring about individual puddles.

#place(top, float: true, [#figure([#block[
  #box(image("../Figures/Puddles/puddles_arch_overview.svg", width: 70%))
  ]],
  caption: [
    Puddles system overview. Each application talks to the Puddles daemon (`Puddled`) to access the puddles in the system. Applications might map the same puddle with different permission.
  ]
)
<fig:puddles-arch-overview>~])

@fig:puddles-arch-overview shows an example database application that demonstrates the benefits of Puddles' approach where the database and logs are partitioned into pools. The application manages a PM database and writes event logs using the #emph[Database app];. A separate #emph[Log reader] process has read-only access to the event logs. Since both the database and the event logs are part of the same global persistent space of a machine, the application can write to both the database and the event log in the same transaction. The application can also have pointers between the event log and the database, and the Puddles system would make sure that they work in any application with permission to access the data.

=== Application Independent Recovery.
<application-independent-recovery.>

In Puddles, the application specifies how to recover from a failure, and the system is responsible for recovering the data after a crash. Applications use Puddles' logging interface to register logging regions with `Puddled`. The logging interface is expressive enough to encode undo, redo, and hybrid logging schemes.

In Puddles, which component applies the logs depends on the context: during normal execution, the application applies the logs (if needed), but after a crash, the system applies them on the application's behalf. In the common case, the only additional overhead for the application is the one-time cost of registering the logging region. This interface adds negligible logging overhead relative to PMDK or other PM libraries.

=== The Puddle Address Space
<the-puddle-address-space.>

`Puddled` maintains a machine-wide shared persistent memory space that all puddles in a system are part of. At any time, an application only has parts of the puddle address space mapped into its virtual address space. A single persistent memory space in a machine allows Puddles to support cross-pool pointers and cross-pool transactions.

Applications allocate and request access to puddles from `Puddled`, which grants them the ability to map the puddle into their virtual address space.

The puddle address space is divided into virtual memory pages where the puddles are allocated as contiguous pages. This global PM range only contains the application's persistent data; other parts of the application's address space, like the text, execution stack, and volatile heaps are still managed using the OS-allocated memory regions. In our implementation of Puddles, we reserve 1~TiB of address space as the global puddle space at a fixed virtual address, disabling Linux's ASLR for the address range. This range is implementation-dependent and is limited only by the virtual memory layout.

=== Native, Relocatable, and Discoverable Pointers
<subsec:pointers>

Puddles contain normal (#emph[i.e.];, neither smart nor fat) pointers to themselves or other puddles. This ensures that normal (non-PM-aware) code can dereference the pointers and read data stored in puddles.

To ensure pointers are meaningful, each puddle must have a current (although not fixed) address that is unique in the machine.

This requirement raises the possibility of address conflicts: If an external puddle (e.g., transferred from another machine) needs to be mapped, its current address may conflict with another pre-existing puddle. In this case, `Libpuddles` will rewrite the pointers when mapping the new puddle into the application's address space. To be able to rewrite pointers, `Libpuddles` stores the type information with allocated objects, allowing it to quickly locate all pointers to support on-demand, incremental relocation (see @subsec:relocation).

=== Puddles Programming Interface
<sec:programming-interface>

To allocate objects, a pool provides a `malloc``()`/`free``()`-style memory management interface. Allocations made through this API might reside in any puddle in the pool. A Pool's `malloc``()` API takes as input the object's type in addition to its size.

#figure([#block[
  #box(image("../Figures/Puddles/pmdk-vs-libpuddles.svg", width: 70%))
  ]],
  caption: [
    List append example using (a) Puddles, which uses virtual pointers, and (b) using PMDK, which uses base+offset pointers.
  ]
)
<lst:puddles-pmdk-list-append>~

Transactions in Puddles are similar to traditional PM transactions (e.g., PMDK-like `TX_BEGIN`...`TX_END`, that mark the start and end of a transaction). `Libpuddles` does not directly manage concurrency or IO in transactions. Instead, like PMDK, it relies on the programmer to use mutexes to implement concurrent transactions and avoid non-transaction-safe IO.

@lst:puddles-pmdk-list-append is an example of a list append function written using both Puddles and PMDK. The code snippet allocates a new node on persistent memory and appends it to a linked list. Puddles' transactions are thread-local, but unlike PMDK, they support writing to any arbitrary PM data and are not limited to a single pool.

Finally, while Puddles has a C-like API and is implemented using C++, similar to PMDK, Puddles could be extended to support other managed languages like Java.

== System Architecture
<system-architecture>

Next, we discuss the details of how Puddles provides a flexible logging interface to enable system-supported recovery, handles recovery in case of a failure, and supports relocating PM data within the virtual address space to provide location independent data. Finally, we complete the discussion with details on various puddle system components.

=== Crash Consistency
<subsec:logging-and-crash-consistency>

Puddles implement centralized crash consistency by providing system support to guarantee that PM data is consistent before any program accesses the data.

To guarantee the consistency of PM data after a crash, the system needs to be able to replay the application's crash-consistency logs.

To support this, `Libpuddles` communicates the location and format of its logs to the puddle daemon before accessing any data. Further, the logging format (a) needs to be able to support a variety of logging methods, (b) should be safe to apply independently of the application after a crash, and (c) should not add significant runtime overhead.

To solve these challenges, Puddles implement a flexible, system-wide, and low-overhead logging format.

#place(top, float: true, [#figure([#block[
  #box(image("../Figures/Puddles/logspace_and_logs.svg", width: 60%))
  ]],
  caption: [
    Application registers a logspace with the system. A logspace space lists all puddles that the application uses to log data for crash consistency.
  ]
)
<fig:logspace-and-logs>~])

#BoldParagraph("Managing logs using log puddles and log spaces")
Puddles organize logs using a directory, called a #emph[log space];, that tracks all the active crash-consistency logs. To simplify the implementation, `Libpuddles` stores both the log space and the logs in designated global puddles not assiciated with any pools. As shown in @fig:logspace-and-logs, the #emph[log space puddle] is a list of #emph[log space entries];, each identifying a #emph[log puddle] that the application is using to store a log. For instance, an application might have one log puddle per thread to support concurrent transactions. Each of these log puddles would have its own entry in the log space. Once registered, the application can update its log space or modify the logs without notifying the daemon.

Logs in the puddle system can span multiple puddles, enabling them to be arbitrarily long. @fig:logspace-and-logs shows an instance of this, where the first log in the log space spans two puddles (Puddle 0 and 1).

#BoldParagraph("Flexible logging format") Applications use a wide range of logging mechanisms (undo~@atlas@george2020go, redo~@mnemosyne, and hybrid~@nvheaps@corundum@pmdk), and Puddles must be flexible enough to support as many as possible. To allow this, Puddles' logging format is expressive enough to cover a wide range of logging schemes and structured enough for `Puddled` to apply them safely after a crash. To achieve flexibility, `Libpuddles` allows the application to write undo- and redo-log entries to a `Puddled` registered log. When the application calls transaction commit, `Libpuddles` processes log entries to be able to recover from a crash.

Puddles ensure that replaying a log can only modify data that the application that created the log could have modified. To accomplish, this libpuddle maintains a persistent record of which puddles an application has access to, and uses this record to check permissions during recovery.

A log in Puddles is a sequence of log entries and includes the metadata to control their recovery behavior. To provide a flexible logging interface, each log entry in Puddles contains the virtual address, checksum, flags field, log data, and the data size. Puddles use a combination of #emph[sequence number] (one for each log entry) and a #emph[sequence range] (one for each log) to control the recovery behavior. For every log, the log entries that have their sequence number within the log's sequence range are valid, allowing `Libpuddles`(or the application) to selectively (and atomically) enable and disable specific types of log entries.

To implement a variety of logging techniques, Puddles' logging interface allows the application to (1) mark log entries to be of different types (e.g., an undo or redo entry). (2) Disable log entries by their type so `Puddled` will skip them during recovery. (3) Specify recovery order (e.g., recover undo-log entries in reverse order). (4) And, verify that the log entry is complete and uncorrupted.

@fig:log-entry-format illustrates Puddles' log and log-entry layout. The "`Sequence Range`" in the log and the "`Seq`" field in log-entry control recovery behavior by specifying which entries will be used during recovery. The "`order`" field specifies the order in which log entries will be applied (forward for redo logging, backward for undo logging). "`Next log Ptr`" and "`Last Log Entry Ptr`" track log entry allocation. And, the checksum, like in PMDK, allows the recovery code to identify and skip any entry that only partially persisted because of a crash. The log's metadata includes a pointer to find the next free log entry, a pointer to the current tail entry, and the maximum size of the log.

#place(top, float: true, [#figure([#block[
  #box(image("../Figures/Puddles/log-entry-format.svg", width: 70%))
  ]],
  caption: [
    Puddles' log-entry and log format.
  ]
)
<fig:log-entry-format>~])

Finally, to keep transaction costs low, every thread caches a reference to the log puddle used on the first transaction of that thread and reuses it for future transactions. This prevents `Libpuddles` from allocating a new puddle and adding it to the log space on every transaction. Once the transaction commits, the log is dropped and is ignored by the `Puddled`.



#BoldParagraph("Example hybrid logging implementation.")
To illustrate the flexibility of Puddle's log format, we will demonstrate how it can implement a hybrid (undo+ redo) logging scheme. Hybrid logging enables low programming complexity for application programmers that use undo logging while allowing libraries to implement their internals using faster but more complex redo logging. For example, PMDK uses hybrid logging to improve performance of allocation/free requests in transactions@pmdk-hybrid-logging. While we implement hybrid logging, the programmer can enable support for undo- or redo-only logging by creating only those entries in the log.

#place(top, float: true, [#figure(image("../Figures/Puddles/hybrid-log-new.svg", width: 100%), caption: "Three stages of hybrid logging TX commit and recovery. Operations are instructions executed during commit stages.") <fig:hybrid-log-desc>~])

#BoldParagraph("Transaction commit.")
The application (perhaps via a library like `Libtx`) commits a transaction in three stages and without communicating with puddled. Some logging schemes may not need all three stages. For instance, a purely redo-based logging scheme could skip the undo stage. This is shown in @fig:hybrid-log-desc with the `sfence` and `clwb` ordering and the sequence numbers used for delineating the stages (elaborated on later in this section). The first two stages work on the undo and redo logs, respectively, and the final stage marks the log as invalid. These three stages are:

+ #emph[Stage 1, Flush undo logged locations] (@fig:hybrid-log-desc#{}a). `Libpuddles` goes through the undo log entries and makes the corresponding locations durable on the PM.

+ #emph[Stage 2, Apply the redo log] (@fig:hybrid-log-desc#{}b). Once all the undo-logged locations are flushed to PM, `Libpuddles` starts copying new data from the redo logs. Redo logged locations were unchanged before the commit, so, `Libpuddles` copies the new data from the log entry to the corresponding memory location.

+ #emph[Stage 3, TX complete] (@fig:hybrid-log-desc#{}c). The transaction is complete, and all changes are durable. The log is marked as invalid.

~

#BoldParagraph("Recovery.")<recovery.>
After a crash on an unclean shutdown, `Puddled` applies any valid logs it finds in PM. The Puddles recovery process depends on during which stage of a transaction commit the application crashed:

+ #emph[Recovery from crash on or before Stage 1 (Rollback)];. First, `Puddled` applies all valid undo-log entries in reverse order.

  At "Stage 1" in @fig:hybrid-log-desc, the undo log entries are still valid, but some locations covered by the undo entries might have been modified before the crash. Thus, on recovery, `Puddled` rolls back the transaction by replaying the undo log in reverse. Which entries to apply and in what order is clear from the sequence range, sequence numbers, and recovery order fields in the log entries.

+ #emph[Recovery from crash on Stage 2 (Roll forward)];. If the application crashed during stage 2, `Puddled` applies the redo-log entries from the log.

  In the example, all the undo-logged locations are durable, and `Libpuddles` might have applied some of the redo log entries. On a crash, the recovery would simply roll the transaction forward by resuming the redo log replay.

+ #emph[Recovery from crash on Stage 3 (TX complete)];. The TX was marked complete, and all changes are durable. No recovery is needed; any logs will be dropped.

After a crash, the daemon compares each log entry's sequence number with the log's sequence range to identify the active stage before the crash. In the hybrid logging example, the application can assign sequence number 1 to the undo log entries and 3 to the redo log entries (@fig:hybrid-log-desc). This assignment allows the `Libpuddles` to mark stages 1, 2, and 3 by setting the log's sequence range to $(0 , 2)$ to only replay the undo logs, $(2 , 4)$ to only replay the redo logs, and $(4 , 4)$ to replay neither.

In Puddles, regardless of whether an entry is an undo or redo log entry, to apply an active log entry, the daemon needs to only copy the entry's content to the corresponding memory location. For example, in undo logging, the entry contains the old data, copying its contents would "undo" the memory location. Similarly, copying contents of a redo log entry would apply the entry, resulting in a "redo" operation.

#BoldParagraph("Logging interface example.")
<logging-interface-example.>
Although the application can directly write to the logs most programmers will use PMDK-like transactions provided by `Libtx` to atomically update PM data and create the logs. To undo and redo log data within a transaction, the programmer uses `TX_ADD()` and `TX_REDO_SET()`, respectively. Once the transaction commits, all changes are made durable.

#figure(image("../Figures/Puddles/consistency-api.svg", width: 80%),
  caption: [
    Linked List using Puddles' programming interface along with the log's state after various operations.
  ]
)
<fig:consistency-api>~

@fig:consistency-api shows an example of a simple linked list implementation to understand the programmer's view of the puddle logging interface. The linked list implementation uses the puddle allocator to allocate a new node (line 4). This new node is automatically undo-logged by the allocator. Next, when the execution of line 8 completes, the log now contains a new undo log entry for the next field of the current tail (). Next, the application redo logs the update to the list's tail pointer (line 12). Being redo logged by the application, this update is performed only on the log; the actual write location will be updated on the transaction commit. Since the application uses hybrid logging, after line 12, the log now contains both undo and redo log entries ().

Once the execution reaches the `TX_END`, `Libpuddles` executes the three stages described in @fig:hybrid-log-desc to commit the transaction and make the changes durable.

#BoldParagraph("Logging design choices.")
An alternative (and superficially attractive) option to keeping a single log for all puddles would be to keep per-puddle logs since this would make puddles more self-contained.

Per-puddle logs, however, would have several problems. First, concurrent transactions on a puddle would require multiple logs per puddle, taking up additional space and adding significant complexity in managing and coordinating these logs. Second, transactions that span puddles (the common case in large data structures) would require a more expensive multi-phase commit protocol.

For logging, Puddles' interface is limited to conventional per-location recovery and does not support implementations that re-execute or resume execution~@clobbernvm@izraelevitz2016failure@liu2018ido, semantic log operations@pronto, or shadow logging in DRAM and flushing it to PM~@liu2017dudetm@castro2018hardware@pangolin. These systems use custom logging techniques that require complex recovery conditions that make it difficult to provide a unified interface.

In addition to persistent memory locations, Puddles logs can contain log entries for volatile memory locations that the applications apply on abort to keep volatile and persistent memories consistent with each other. During recovery after a crash, `Puddled` ignores these logs as the destination address does not belong to the global puddles space and the volatile state is lost.

=== Location Independence
<subsec:relocation>

Puddles' ability to relocate PM data within the virtual address space allows it to support location independence and movability with native pointers. Thus, unlike existing PM programming solutions, Puddles allows applications to relocate PM data between pools or create copies of PM data without reallocating and rebuilding the contained data structures in a new PM pool.

In the common case where the assigned address of PM data does not conflict with any existing puddles, `Libpuddles` can simply map the puddle to the application's address space. However, if the puddle's address (@subsec:pointers) is already occupied, Puddles support moving data in the global persistent address space. The ability to move data on conflict is essential to support shipping PM data between machines.

Pointer translation in `Libpuddles` works by incrementally rewriting pointers in puddles. `Libpuddles` maps a puddle on demand and maintains a "#emph[frontier];" of puddles that are unmapped but have a reserved and available location in the global persistent address space.

Frontier puddles 1) are not yet mapped but their eventual location in the global persistent address space is reserved, and 2) are the target of a pointer in a mapped puddle.

Specifically, when an application dereferences a pointer to a frontier puddle, it causes a page fault that `Libpuddles` intercepts. In response, `Libpuddles` maps it to the puddle's assigned virtual address or, on a conflict, to an unreserved range. Next, `Libpuddles` iterates through all the pointers in the puddle and checks if the pointer's destination address is already reserved. If the address is reserved, `Puddled` assigns the puddle pointed by the pointer a new address. This effectively relocates the target puddle in the Puddles' global address space, even if the puddle has not yet been opened or mapped to this location. To accelerate finding pointers in a puddle's internal heap, puddles use allocator metadata to locate internal heap objects (@sec:allocator).

Once all the pointers in a puddle are rewritten, `Libpuddles` makes it available to the application to access. At this point, only the puddle requested by the application is mapped. If the application dereferences any pointer that points to an unmapped puddle, it generates another page fault.

By marking puddles that have been assigned a new address and have not been mapped, Puddles create a cascading effect of #emph[on-demand] pointer rewrite where the pointers are only rewritten when the data is mapped. Further, since all puddles in a machine are part of the same virtual memory address range, `Libpuddles` can transparently catch access to any unmapped data that is part of this range and map it to the application's address space.

Finally, `Puddled` persistently tracks puddles that were part of a frontier, including puddles that are not yet mapped. In case the machine crashes with some puddles unmapped, the next time one of the puddles from a frontier is mapped, the relocation process resumes.

#BoldParagraph("Pointer maps.") For the puddle system to rewrite pointers, it needs to know their location. Puddles solve this problem by requiring the application to register #emph[pointer maps] with `Puddled` for each persistent type used by the application. These pointer maps are simply a list, where each element contains the offset of a pointer within the object and the type of the pointer.

To allow Puddles to rewrite pointers, every allocation in Puddles is associated with a type ID, stored as a 64-bit identifier in the allocator's metadata along with the allocated object. Every `class` or `struct` with a unique name corresponds to a unique type in Puddles. Further, since allocations of a type share their layout, Puddles only need one pointer map per type. To ensure each unique class's name results in a unique type, Puddles rely on C++'s `typeid()` operator, just like PMDK~@pmdk-typeid. `typeids` are generated using the Itanium ABI used by gcc and clang, which results in consistent `typeid` across at least gcc v8-12 and clang v7-12.

The overhead of registering pointer maps with `Puddled` is negligible since the number of unique objects an application uses is typically much greater than the number of unique types it uses.

Similar to the centralization of logs discussed in @subsec:logging-and-crash-consistency, we centralize the pointer maps in `Puddled` to simplify puddle metadata management. `Puddled` stores the pointer maps in a simple persistent memory hashmap along with its other metadata. While pointer maps could be stored in each puddle for the types in the puddle, doing so would require dynamic memory management of the puddle's metadata. Since the overhead of storing the pointer map information with `Puddled` is low, and it is easy for `Puddled` to export its pointer maps along with exported puddles, we found the complexity of storing pointer maps in puddles rendered it not worth pursuing.

#BoldParagraph("Relocation on import.")
Puddles allow sharing of PM data by "exporting" part of the global persistent space. Once exported, PM data retains its in-memory representation, allowing Puddles to "import" it back into the same address space as a copy, or into a different machine.

When importing data, the application asks `Libpuddles` to map a pool into its address space. Pools are a collection of puddles with a designated root puddle, the puddle that holds the pool's root object. Puddles support relocation on import by first mapping the root puddle of the pool. Once `Libpuddles` maps the root puddle, it can begin its pointer rewrite operation and relocate any conflicting data.

Location independence in Puddles extends to support movability by allowing the application to export the underlying data in its in-memory form. Exporting pools in Puddles does not require any serialization and exports the raw in-memory data structures. Once exported, the PM data can be re-imported into the machine's global PM space with no user intervention.

#BoldParagraph("Referential Integrity.") While the referential integrity of exported data is a concern, applications are expected to only export self-contained pools. In Puddles, this can be accomplished by limiting inter-pool links or using programming language support to prevent inter-pool pointers.

=== Puddle Layout
<subsec:puddle-implementation>

A puddle has two parts, a header, and a heap. Every puddle in the global puddle PM space has a 128-bit universally unique identifier (UUID). The header stores the puddle's metadata information like the puddle's UUID, its size, and allocation metadata. The heap is managed by the `Libpuddles`' allocator and contains all allocated objects and their associated type IDs. We have configured Puddles to have 4~KiB of header space for every 2~MiB of heap space (0.2% overhead).

=== Pools
<subsec:pools>

The Puddles system provides a convenient #emph[pool] abstraction on top of puddles to create data-structures that span puddles. Programmers use a pool's `malloc``()`-like API to avoid needing to manually manage objects between puddles.

Internally, `Puddled` and `Libpuddles` identify a pool as a collection of puddles and a designated "root" puddle. The root puddle of a pool is the puddle that contains the root of the data structure contained in that pool.

After `Puddled` verifies that the application has access permission to a pool, the library receives the pool's root puddle and maps the puddle to its virtual memory address space. `Libpuddles` then maps the puddle lazily using the on-demand mapping mechanism described in @subsec:relocation.

Segmenting the persistent memory address space into small puddles to provide the pool interface enables Puddles to relocate, share, and recover individual objects with fine granularity, resulting in low performance and space overhead. For example, puddles limit the cost of pointer rewrite when importing large PM data, limiting the overhead to a few puddle at a time.

=== Object Allocator
<sec:allocator>

While each puddle can be independently used to allocate objects, applications typically use pools to allocate objects. Using a pool makes it easier for the application to package and send its data structures to a different address space. Further, to track the allocation's type, pool's `malloc``()` API takes as input the type of the object in addition to its size.

Since the object allocator always allocates the first object at a fixed offset (root offset) in the puddle, when the application asks `Libpuddles` for the root object, `Libpuddles` can return its address using a simple base and offset calculation.

Object allocations in puddles are handled in the userspace by `Libpuddles`, similar to PMDK. Puddles use a two-level allocator where per-type slab allocators manage small allocations (\< 256~B). Large allocations are allocated from a per-puddle buddy allocator. Two-level allocator hierarchy allows Puddles to perform fast allocations of both large and small sizes.

=== Access Control
<sec:access-control>

In the puddle system, applications must not access puddles that they do not have permission to, while allowing `Puddled` to manage all puddles in a machine. To achieve this, `Puddled` stores each puddle in a separate file on the PM file system. These files are exclusively owned by `Puddled`, and no other process can access them. For applications to access a puddle, `Puddled` maintains a separate, application-facing, UNIX-like permission model.

When an application requests access to a puddle over the UNIX-domain socket, puddled verifies the caller's access using its group ID and user ID. If approved, puddled returns a file descriptor for the requested puddle using the `sendmsg(2)` system call. This file descriptor serves as a capability, letting the application access the underlying puddle without any direct access to the underlying file. Upon receiving the file descriptor, `Libpuddles` maps the puddle to the application's address space and closes the file descriptor. As applications must communicate with `Puddled` to request access to puddles, `Puddled` starts before any other process in the system and controls access to PM data.

While sending file descriptors simplifies puddle management and mapping, an application can still forward them to other processes. However, this limitation is inherent to the UNIX design, i.e., the same vulnerability applies to files, and thus, we assume a similar adversary model. Had we implemented `Puddled` inside the kernel rather than as a privileged daemon, we could have allowed `Puddled` to directly update the application's page tables to map the puddle. This would eliminate the need for sending the file descriptor through the domain socket. However, we decided to leave `Puddled` in user space because it makes it much easier for users to adopt Puddles. Instead of needing to install a custom-built kernel, users of Puddles only need to run `Puddled` and link to our libraries. Finally, managing puddles as files on a DAX-mapped file system has the added benefit of not needing a puddle-scale allocator.

#BoldParagraph("Recovery.")
`Puddled` extends the puddle access control to recovery and prevents a process from using recovery logs to modify unwritable addresses. During log replay, `Puddled` recreates the mapping for the crashed process by mapping all puddles in the machine-local persistent address space. Recreating the puddle mapping limits `Puddled`'s recovery to locations that the process had write permission to before the crash. If `Puddled` identifies an invalid log, instead of dropping the log, it will be marked as invalid and will not be replayed as the PM data is possibly in a corrupted state. While this may result in denial of service by a malicious application, the effect would be limited to the data accessible by the application.

Let us explore a scenario where a potentially malicious application logs data and then frees the corresponding puddle. In this context, Puddles ensures data integrity by only allowing access to applications with proper permissions. Two scenarios can arise: (1) a new application acquires the freed puddle but allows the original application access to the puddle, potentially risking data corruption during recovery. However, the malicious application already had access to the data before the crash, and thus the security guarantees are unaffected. (2) If the puddle is unallocated during recovery, or if another application acquires the puddle but does not permit the original application access to its data, the recovery after a crash will fail as the malicious application no longer has access to the puddle, preserving data integrity.

== Results
<sec:results>

#place(top, float: true, [#figure(
  caption: [System Configuration],
  table(
      columns: (auto, auto, auto, auto),
      
      // inset: 10pt,
      align: horizon,
      table.header(
        [*Component*], [*Details*], [*Component*], [*Details*]
      ),
      [CPU & HW Thr.], [Intel Xeon 6230 & 20], [Linux Kernel], [v5.4.0-89],
      [DRAM / PM], [93~GiB / 6×128~GiB], [Build system], [gcc 10.3.0]
  )
)<tab:sysconfig>~])


Puddles perform as fast or faster than PMDK and are competitive with state-of-the-art PM libraries across all workloads while providing system-supported recovery, simplified global PM space, and relocatability. We evaluate Puddles using a BTree, a KV Store using the YCSB benchmark suite, a Linked List, and several microbenchmarks.

@tab:sysconfig lists the system configuration. For all experiments, we use Optane DC-PMM in App Direct Mode. All workloads use undo-logging for both the application and allocator data logging except for the linked list workload.

=== Microbenchmarks
<subsec:microbenchmarks>

This section presents three different measurements to provide insights into how Puddles perform: (a) performance of Puddles' API primitives to compare and contrast them with PMDK, (b) average latency and frequency of `Puddled` operations, and (c), the time taken by different parts of Puddles' relocatability interface.

#place(top, float: true, [
#figure(
  align(center)[#table(
    columns: 3,
    align: (left,center,center,),
    table.header(table.cell(align: center)[#strong[Operation];], [#strong[Puddles];], [#strong[PMDK];],),
    table.hline(),
    [`TX NOP`], [11.0~ns], [142~ns],
    [`TX_ADD` (`8B/4kB`)], [0.04/1.1~μs], [0.3/2.2~μs],
    [`malloc` (`8B/4kB`)], [0.1/6.8~μs], [0.4/0.4~μs],
    [`malloc`+`free` (`8B/4kB`)], [5.6/6.0~μs], [2.0/3.0~μs],
  )]
  , caption: [Mean latency of Puddles and PMDK primitives.]
  , kind: table
  )<tab:avg-lat>~
])


#BoldParagraph[API primitives.];<par:api-primitives> Measurements in @tab:avg-lat show that across most API operations, Puddles outperform PMDK. To measure the overhead of starting and committing a transaction, we measure the latency of executing an empty transaction--`TX NOP`. Since Puddles' transactions are thread-local and do not allocate a log at the beginning of a transaction, they are extremely lightweight. For an empty transaction, Puddles' overhead only includes a single function call to execute an empty function.

For undo-logging operations (`TX_ADD`), Puddles have latencies similar to PMDK. However, we observe slower allocations (`malloc``()`) and de-allocations (`free``()`) for Puddles. The performance difference is an artifact of the implementation. For example, Puddles uses undo logging while PMDK uses redo logging for the allocator.

#BoldParagraph[Daemon primitives.] Since the Puddles system offers application-independent recovery, it needs to talk to `Puddled` to allocate puddles and perform other housekeeping operations. The daemon communicates with the application using a UNIX domain socket. On average, a round-trip message (no-op) between the daemon and the application takes 46.9~μs. Most daemon operations take in the order of a few hundred microseconds to complete.

During execution, the function `RegLogSpace` is called once to register a puddle as the log space and takes on average 134.0~μs. `GetNewPuddle` and `GetExistPuddle` are called every time the application needs a puddle. Internally, `Puddled` manages each puddle as a file and returns a file descriptor for puddle requests. Allocating a new file slows down `GetNewPuddle`, and it takes considerably longer (1705.0~μs) than calls to `GetExistPuddle` (125.3~μs). Even though the call to `GetNewPuddle` is relatively expensive, `Libpuddles` mitigates their overhead by caching a few puddles when the application starts. Caching puddles in the application avoids calls to the daemon when the application runs out of space in a puddle. As we will see with the workload performance, even with relatively expensive daemon calls, Puddles outperform PMDK.

Finally, in addition to the runtime overheads, recovery from a crashed transaction takes 110.1~μs in Puddles.

#BoldParagraph[Relocatability primitives.] On a request to export a pool, `Puddled` creates copies of the puddles and the associated metadata (e.g., pointer maps). Data export cost, therefore, scales linearly with the size of the PM data and includes a constant overhead per puddle. Exporting a pool takes 0.3~s for 16~B and 0.5~s for 16~MiB of PM data in our implementation. Importing data, on the other hand, is nearly free, as it only includes registering the imported puddles with the daemon (1.5~ms for both 16~B and 16~MiB). After import, if the imported data conflicts with an existing range, the puddle system automatically rewrites all the pointers in the mapped puddle. During pointer rewrite, every pointer in the pool must be visited, so runtime scales linearly with the number of pointers in the pool. Rewriting pointers takes 0.2~ms for 20 pointers, 1.6~ms for 2000 pointers, and 0.5s for 2~million pointers.

#BoldParagraph[Correctness Check.] To ensure the correctness of Puddles' logging implementation, we inject crashes into Puddles' runtime and run system-supported recovery. We do this for undo and redo logging and find that Puddles recover application data to a consistent and correct state every time.

=== Workload evaluation
<subsec:workload-evaluation>

#place(top, float: true, [#figure(image("../Figures/Puddles/linkedlist.svg"),
  caption: [
    Puddles' performance against PMDK and Romulus for singly linked list (lower is better). Native pointers offer a significant performance advantage for Puddles.
  ]
)<fig:linkedlist-perf>~])


To evaluate Puddles' performance, this section includes results for several workloads implemented with Puddles, PMDK, Romulus, go-pmem, and Atlas. Further, to understand the overhead of fat-pointers in PMDK, we used stack samples from PMDK workloads and find that the overhead of fat-pointers ranges from 8.5% for btree, which has multiple pointer dependencies, to 0.76% for the KV-store benchmark that uses fewer pointers per request by making extensive use of hash map and vectors. Finally, across workloads, the daemon primitives result in an additional overhead of about 0.2~ms. This overhead is primarily from registering the first log puddle during the transaction of the benchmark.

#BoldParagraph[Linked List] We compare Puddles' implementation of a singly linked list against PMDK and Romulus. @fig:linkedlist-perf compares the performance of three different operations (each performed 10 million times): (a) Insert a new tail node, (b) delete the tail node, and (c) sum up the value of each node. For the insert, PMDK and Puddles perform similarly and Romulus performs slightly worse, but delete and sum in Puddles outperform PMDK by a significant margin. This performance gap is from the native pointers' lower performance overhead and better cache locality in Puddles. In addition to Puddles' undo logging implementation presented here, we evaluated a hybrid log implementation using undo logging for the allocator and redo logging for the application data and found the performance to be similar to the undo-logging only version, that is, within 5%.

#place(top, float: true, [#figure(image("../Figures/Puddles/btree.svg"),
  caption: [
    Performance of Puddles, PMDK, and Romulus's implementation of an order 8 Btree (lower is better).
  ]
)<fig:btree-perf>~])


#BoldParagraph[B-Tree.] @fig:btree-perf shows the performance of an identical order 8 B-Tree implementation in PMDK, Puddles, and Romulus. Both the keys and the values are 8 bytes. Similar to the Linked List benchmark, Puddles perform as fast as or better than PMDK across the three operations while being competitive with Romulus. In summary, Puddles' native-pointer results in a much faster (3.1$times$) performance over PMDK for search operations.

#figure(
  image("../Figures/Puddles/simplekv.svg"),
  caption: [
    KV Store implementation using different PM programming libraries, evaluated using YCSB workloads. Workload D and E use latest and uniform distribution, respectively, while all other workloads use zipfian distribution~@ycsb.
  ]
)<fig:kv-store-ycsb>~

#BoldParagraph("KV-Store.") To evaluate Puddles' performance in databases, we evaluate PMDK's Key-Value store using Puddles(using undo logging), PMDK, Atlas~@atlas, go-pmem~@george2020go, and Romulus~@correia2018romulus. @fig:kv-store-ycsb shows the performance across these libraries using the YCSB~@ycsb benchmark. For each workload, we run a 1 million keys load workload followed by a run workload with 1 million operations. Across the workloads, Puddles are at least as fast and up to 1.34$times$ faster than PMDK. Against Romulus, Puddles is between 36% slower to being equally fast across the YCSB workloads. Romulus's performance improvement is from its use of DRAM for storing crash-consistency logs. While Puddles' implementation is slower than Romulus, Puddles' relocation and native pointer support is compatible with in-DRAM logs and could be used to improve its performance.

#figure(image("../Figures/Puddles/euler_throughput.svg"),
  caption: [
    Multithreaded workload that processes 1/n$""^(upright("th"))$ of the array per thread.
  ]
)
<fig:euler-throughput>~

#BoldParagraph[Multithreaded scaling.];<par:multithreading> To study the multithreaded scalability of Puddles, we used an embarrassingly parallel workload that computes Euler's identity for a floating-point array with a million elements. @fig:euler-throughput shows the normalized time taken by the workload with the increasing thread count scales linearly and is not limited by Puddles' implementation. In the benchmark, each worker thread works on a small part of the array at a time using a transaction. The workload's throughput scales linearly with the number of threads until it uses all the physical CPUs (20); increasing the number of threads further still results in performance gains, albeit smaller. Puddles' asynchronous logging interface, along with thread-local transactions, allows it to have fast and scalable transactions.

=== Relocation: Sensor Network Data Aggregation
<subsec:relocation-exp>

#place(bottom, float: true, [#figure(
  image("../Figures/Puddles/data-agg.svg"),
  caption: [
    #strong[Data Aggregation Workload.] Independent sensor nodes modify copies of pointer-rich data-structures and a home node aggregates the copies into a single copy.
  ]
)<fig:data-agg>~])

Puddles' ability to relocate data allows it to merge copies of PM data without performing expensive reallocations or serialization/de-serializations. In contrast, applications using traditional PM libraries cannot clone and open multiple copies of PM data because they contain embedded UUIDs or virtual memory pointers.

To demonstrate the ability to relocate PM data across machines, we model a sensor network data-aggregation workload that combines several copies of PM data structures together. @fig:data-agg shows the processing pipeline for this workload. A home node copies a PM-data structure to multiple independent sensor nodes that have their own puddle space. The independent nodes modify these copies and upload the result back to the home node which aggregates the states into a single data structure. Each node modifies the state data using Puddles' transactions and can crash during writes. To model independent nodes with isolated persistent address spaces, we run the nodes in isolated docker containers.

Puddles' ability to resolve address space conflicts in PM data and support for aggregating data allow the nodes to export their state as a portable format to the file system. The home node aggregates the states by reopening the data from each node, and Puddles seamlessly rewrite all the pointers to make the data available for access. PMDK, on the other hand, does not support reading multiple copies of the same data within a single process. For the home node to aggregate the state, it needs to open each copy sequentially and reallocate the data into a larger pool.

#figure(image("../Figures/Puddles/data-agg-breakdown.svg"),
  caption: [
    Total time taken by PMDK and Puddles to aggregate PM data from 200 sensor nodes.
  ]
)
<fig:form-demo>~

@fig:form-demo shows the total time spent and Puddles' break down while aggregating states from 200 nodes with 100 to 1600 state variables each. Since PMDK needs to reallocate all the data, it is between 4.7$times$ to 10.1$times$ slower than Puddles. For Puddles, the aggregation has a constant import overhead of 0.2~s, while pointer rewrite overhead scales with the number of elements and increasingly dominates the execution.

== Related Work
<sec:related>

Prior persistent memory works have used a variety PM pointer formats; PM Libraries often use non-standard pointer formats that require translation to use~@pmdk@corundum@nvheaps@bittman2020twizzler or do not allow the programmer to reference data across PM regions, e.g., pools~@pmdk@corundum@nvheaps, limiting PM programming flexibility. Some persistent memory programming libraries like Pronto~@pronto simplify PM programming by semantically recording updates like linked list inserts instead of individual memory writes. Unlike Puddles, Pronto and Romulus~@correia2018romulus use DRAM for the working copy of the application data.

Researchers have previously proposed having a global unified virtual memory space that all applications allocate from~@redell1980pilot@bittman2019tale@kale1997design@bittman2020twizzler. TwizzlerOS~@bittman2020twizzler is one such system for persistent memory that proposes a global persistent object space similar to Puddles. Puddles differ from TwizzlerOS in three major ways: (a) recovery in TwizzlerOS, like PMDK, relies on the application, (b) unlike native virtual pointers in Puddles, TwizzlerOS uses redirection tables and index-based pointers that can have up to 2 levels of indirections, and (c) finally, unlike Puddles, TwizzlerOS does not support exporting data structure out of its global object space. However, Puddles' recovery and relocation support are orthogonal to TwizzlerOS and can be implemented as an extension to TwizzlerOS. While TwizzlerOS offers a new PM model, the open-source version does not support crash-consistent allocations, making meaningful comparison impossible. And thus, we do not evaluate TwizzlerOS against Puddles.

Similar to TwizzlerOS, several previous OS works have looked into using a single per-node unified address space. Opal~@chase1992opal, Pilot~@redell1980pilot, and SingularityOS~@hunt2007singularity all provide a single address space for all the processes in a system. While OS like Opal support single, unified address space with the ability to address persistent data, they still suffer from the same limitations that today's PM solutions do.

Opal, for example, offers a global persistent address space, yet it lacks consistency or location independence. Data in Opal is inconsistent until a PM-aware application with write permissions reads it. Puddles, on the other hand, guarantee system-supported recovery with no additional cost other than the one-time setup overhead. Further, since Opal has no information about the pointers embedded in the data, like PMDK, it requires expensive serialization/deserialization to replicate data structures within the address space. No support for pointer translation also means that Opal cannot relocate data structures on an address conflict when importing data from a different address space.

GVMS~@heiser1993mungi also introduces the idea of a singular global address space, but for all the application data and shares it across multiple cluster nodes to provide shared memory semantics. In contrast, Puddles provide a unified address space only for PM while still using traditional address spaces for isolation and security.

Hosking #emph[et al.]~@hosking1993object present an object store model for SmallTalk that maps objects missing from the process address space on a page fault similar to Puddles, but relies on SmallTalk's runtime indirection for checking and rewriting pointers. Moreover, their solution does not allow storing native pointers in storage, requiring translating pointers every time persistent data is loaded. In contrast, Puddles does not depend on a specific runtime for identifying pointers, and provides application independent recovery and location independence.

Wilson and Kakkad et al.~@wilson1991pointer@kakkad1999address propose pointer translation at page fault time similar to Puddles, however, their solution suffers from several problems. One of the major limitations is no support for objects that span multiple pages as each page can be relocated independently, breaking offset-based access into the object. Puddles solve this problem by translating pointers at puddle granularity, allowing objects to span pages. Further, their solution does not support locating pointers in persistent data, and unlike Puddles' pointer maps, they leave it as future work. Finally, unlike direct-access (DAX) support in Puddles, their solution requires mapping data to the page cache as the data is stored in a non-native pointer format.

== Conclusion
<sec:conclude>

Current PM programming solutions' choices introduce several limitations that make PM programming brittle and inflexible. They fail to recover PM data to a consistent state if the original application writing the PM data is no longer available or if the user no longer has write permission to the data. Existing PM systems also non-optimally choose among pointer choices that result in unrelocatable PM data and, in some cases, performance overhead.

We solve these problems by providing a new PM programming library--Puddles that supports application-independent crash recovery and location-independent persistent data. To support this, Puddles register logs with the trusted daemon that manages and allocate persistent memory and automatically replays logs after a crash. The puddle system has a single global PM address space that every application shares and allocates from. A global address space and PM data relocation support allows the use of native, unadorned pointers.

Puddles' native virtual pointers provide a significant performance improvement over PMDK's fat pointers. Moreover, Puddles support the ability to relocate PM data seamlessly and faster than traditional solutions.

== Acknowledgement<acknowledgement>

This chapter contains material from "Puddles: Application-Independent Recovery and Location-Independent Data for Persistent Memory," by Suyash Mahar, Mingyao Shen, T. J. Smith, Joseph Izraelevitz, and Steven Swanson, which appeared in the proceedings of the nineteenth European Conference on Computer Systems (EuroSys 2024). The dissertation author is the primary investigator and the first author of this paper.

