#import "../macros.typ": *

Communication within the datacenter needs to be fast, efficient, and secure against unauthorized access, rogue actors, and buggy programs. Remote procedure calls (RPCs)@grpc@thriftrpc are a popular way of communicating between independent applications and make up a significant portion of datacenter communication, particularly among microservices@barroso2003web@luo2021characterizing. However, RPCs require substantial resources to serve today's datacenter communication needs. For instance, Google reports@google-rpc-study that in the tail (e.g., P99), requests spend over 25% of their time in the RPC stack. One of the significant sources of RPC latency is their need to serialize/deserialize and compress/decompress data before/after transmission.

Shared memory offers an exciting alternative by enabling multiple containers on the same host to share a region of memory without any explicit copies behind the scenes. While applications can send RPCs by serializing and copying data to the shared memory region, an attractive alternative is to share pointers to the original data, significantly lowering their CPU usage.

However, accesses to shared memory raise several safety concerns. Shared memory eliminates the traditional isolation of the sender from the receiver that serialized networking provides. For example, the sender could concurrently modify shared data structures while the receiver processes them, leading to unsynchronized memory sharing between mutually distrustful applications. This lack of synchronization can result in a range of potentially dire consequences.

Additionally, if applications share pointer-rich data structures over shared memory, they need to take special care in making sure the pointers are not invalid or dangling.

To solve these issues, we propose MemRPC, a shared memory-based RPC library that exposes the benefits of shared-memory communication while addressing the pitfalls described above. Using MemRPC, clients and servers can directly exchange pointer-rich data structures residing in coherent shared memory. MemRPC is the first RPC framework to provide fast, efficient, and scalable shared memory RPCs while addressing the security and scalability concerns of shared memory communication.

MemRPC provides the following features:

+ #emph[High-performance, low-latency RPCs.] MemRPC uses shared memory to provide faster RPCs than existing frameworks.

+ #emph[Preventing sender-receiver concurrent access.] MemRPC prevents the sender from modifying in-flight data by restricting the sender's access to RPC arguments while the receiver is processing them.

+ #emph[Lightweight checks for invalid and wild pointers.] MemRPC provides a lightweight sandbox to prevent dereferencing invalid or wild pointers while processing RPC arguments in shared memory.

+ #emph[API compatibility.] MemRPC provides eRPC@erpc()-like API when sending RPCs with traditional serialized data.

Using MemRPC, applications can construct pointer-rich data structures with a `malloc``()`/`free``()`-like API and share them as RPC arguments. Clients can choose whether to share the RPC arguments with other clients or keep them private to the server and the client. Moreover, clients can access the data without deserializing it, traverse pointers within the argument if they are present, and only access the parts of the arguments they need.

In existing systems, MemRPC can provide fast communication between co-located containerized services, but Compute Express Link 3.0 (CXL 3.0) will extend its reach across servers. CXL 3.0 will provide multi-host shared memory, offering an exciting alternative by providing hardware cache coherency among multiple compute nodes. However, CXL memory coherence will likely be limited to rack-scale systems@cxl-switch. MemRPC must provide a reasonable backup plan if CXL is not available. And, multi-node shared memory for communication results in challenges with availability and memory management, for example, memory leaks involving multiple hosts. To prevent data loss or memory leaks, MemRPC must notify applications of shared memory failures, and limit shared memory consumption.

MemRPC addresses CXL's limited scalability by implementing a RDMA-based distributed shared memory (DSM) fallback. To coordinate memory management and decide between CXL and RDMA-based communication, MemRPC includes a global orchestrator.

We compare MemRPC against several other RPC frameworks built for RDMA, TCP, and CXL-based shared memory. MemRPC achieves the lowest round-trip time and highest throughput across them for no-op RPCs. We showcase MemRPC's ability to share complex data structures using a JSON-like document store and compared against eRPC@erpc, gRPC@grpc, and ZhangRPC@zhang2023partial. Our results for MemRPC running over CXL 2.0 show a 8.3$times$ speedup for building the database and a 6.7$times$ speedup for search operations compared to the fastest RPC frameworks. In the DeathStarBench social network microservices benchmark, MemRPC improves Thrift RPC's maximum throughput by 10.0%. However we find that the benchmark's performance is primarily constrained by the need to update various databases on the critical path.

The rest of the chapter is structured as follows: @sec:background presents the overview of RPCs and their limitations. @sec:overview-first describes and evaluates MemRPC in its most simple form, shared memory buffers across containers. @sec:overview-third introduces MemRPC's powerful pointer-rich RPC interface and @sec:overview-second extends MemRPC to use CXL-based multi-node shared memory. Finally, we discuss works related to MemRPC in @sec:rpcool-related and conclude in @sec:snapshot-conclude.


== RPCs in Today's World
<sec:background>

Modern RPC frameworks grew from the need to make function calls across process and machine boundaries, making programming distributed systems easier~@birrell1984implementing. These RPCs provide an illusion of function calls while relying on a layer cake of underlying technologies that results in lost performance~@google-rpc-study. For example, RPC frameworks waste a significant number of CPU cycles on serializing and deserializing RPC arguments to send them over traditional networking interfaces~@kanev2015profiling.

Existing RPC libraries ignore potential performance savings from leveraging shared memory when it is available. To better understand the attendant challenges, let us examine the structure and limitations of modern RPC systems. Then, we will follow with a discussion of how shared memory can alleviate these problems.

RPCs provide an interface similar to a local procedure call: the sender makes a function call to a function exported by the framework~@grpc@thriftrpc. The RPC framework (or the application) serializes the arguments and sends them over the network to the receiver. At the receiver, the RPC framework deserializes the arguments and calls the appropriate function.

While RPC frameworks provide a familiar abstraction for invoking a remote operation, the underlying technology used results in several limitations.

First, to enable communication over transports like TCP/IP, RPC frameworks serialize and deserialize RPC arguments and return values. This adds significant overhead to sending complex objects (e.g., the lists and maps that make up a JSON-like object in memory).

Second, most RPC frameworks do not support sharing pointer-rich data structures due to different address space layouts between the sender and the receiver. Applications can circumvent this by using "smart pointers"~@zhang2023partial or "swizzling"~@wilson1992pointer pointers, but both of these add additional overheads.

Third, the underlying communication layer limits today's RPC frameworks' performance. For example, the two common RPC frameworks, gRPC~@grpc and ThriftRPC~@thriftrpc rely on HTTP and TCP, respectively. Some RPC frameworks like eRPC~@erpc exploit the low latency and high throughput of RDMA to achieve better performance but are still limited by the underlying RDMA network.

== RPCool
<sec:overview-first>

RPCool is a zero-copy framework designed for fast and efficient RPC-based communication between hosts connected via shared memory. The shared memory can be on a single server shared between two containerized services or on two different servers that share memory via CXL 3.0. RPCool's underlying mechanism supports pointer-rich RPCs, allowing applications to allocate complex, pointer-rich data structures directly in the shared memory while maintaining safety and isolation. RPCool libraries can also emulate conventional RPC semantics using these mechanisms.

This section describes and evaluates how RPCool enables processes on the same host to send RPC over local shared memory. Later, @sec:overview-third discusses how an application can take advantage of RPCool's powerful pointer-rich RPC interface. Then, @sec:overview-second extends RPCool to support CXL-based shared memory, enabling RPCool's to take advantage of multi-host shared memory while outperforming traditional RPCs.

To send an RPC with RPCool, an application first requests a shared memory buffer, then constructs or, in legacy applications, serializes its data in the buffer, and finally sends the RPC to the receiver. RPCool makes the buffer available to the receiver over shared-memory, requiring zero-copy between sender and receiver. This interface is similar to traditional RDMA-based RPCs like eRPC@erpc, where the sender obtains an RDMA buffer, which the RPC library then copies to the receiver.

While shared-memory RPCs enable low-overhead, efficient communication, a naive implementation would sacrifice the isolation that traditional TCP and RDMA based communication provides. For example, consider the eRPC model, after the sender sends an RPC, it can no longer modify the arguments of the RPC as the library creates a new, unshared copy of the buffer for the receiver. By contrast, with shared-memory RPCs, both the sender and the receiver have access to the same shared memory region.

To address this, RPCool needs to prevent concurrent access to shared data. RPCool should let applications take exclusive access of shared memory data to prevent malicious (or buggy) applications from concurrently modifying it. Shared memory RPCs also face the challenge of communication between servers. Ideally, RPCool should not restrict applications to a single host. RPCool achieves this by providing eRPC-like API, enabling RPCool to use eRPC as its backend when shared memory is not available.

In this section, we look at an overview of RPCool's design and how RPCool addresses these challenges.

=== RPCool Architecture
<memrpc-architecture>
RPCool uses shared memory to safely communicate between processes. The framework consists of userspace components, a trusted daemon, and modifications to the OS kernel.

In userspace, the RPCool library, `librpcool`, provides APIs for connecting to a specific process using RPCool, sending/receiving RPCs, and managing shared memory objects. `librpcool` relies on RPCool's support in the kernel which it communicates with via the daemon. The daemon and the kernel provide RPCool's security guarantees and map the shared memory regions into the process's address space.

RPCool's architecture includes channels and connections to provide TCP-like communication primitives, manage shared memory, and support for mutual exclusion using #emph[sealing];.

#figure(image("../Figures/rpcool/sealing-summary.svg", width: 67%),
  caption: [
    Sealing overview.
  ]
)
<fig:sealing-summary>

\

=== Channels and Connections
<channels-and-connections>

Channels and connections are the basic units for establishing communication between two processes in RPCool. Creating a channel in RPCool is akin to opening a port in traditional TCP-based communication.

Once a channel is open, clients can connect to it and receive a #emph[connection] object that provides access to the connection's shared-memory heap. Every channel in RPCool is identified by a unique, hierarchical name.

Connection heaps hold the connection's RPC buffers, RPC queues to send and receive RPCs, and other metadata. Channels in RPCool automatically use either shared memory or fall back to eRPC, depending on whether the server and client can share memory with each other.

=== Shared Memory Management
<shared-memory-management>
The RPCool daemon tracks applications and shared memory regions so RPCool can cleanup after applications crash and garbage collect orphaned heaps.

To limit the amount of shared memory a process can amass, the daemon enforces a configurable shared-memory quota. The quota limits the amount of heap memory a process has access to at any time, forcing applications to return unused heaps to the kernel.

=== Shared Memory Safety Issues
<shared-memory-safety-issues>
When using shared memory to share data structures, there is a risk that a sender might concurrently modify an RPC's arguments while the receiver is processing them. In an untrusted environment, a malicious sender could exploit this to extract sensitive information from the receiver or crash it. While servers usually validate received data, they must also ensure that the sender cannot modify the shared data once it has been validated.

RPCool prevents the sender from modifying RPC arguments while the receiver processes them by revoking write access to the arguments for the sender, thus #emph[sealing] the RPC (@fig:sealing-summary). When an RPC is sealed, the sender cannot modify the arguments until the receiver responds to the RPC.

RPCool's safety mechanisms are designed to limit the effects of a compromised application/microservice. In RPCool's threat mitigation, we assume that the daemon, the kernel, and the hardware are trusted. If a malicious actor compromises an application, RPCool should not allow the malicious actor to access unauthorized memory regions, crash other applications, or extract sensitive information from those applications. These protections are based on the assumption that application validates the data it received before processing it. We assume the receiver of the RPC validates the its arguments as it would with a conventional RPC system.

=== Sealing RPC Data to Prevent Concurrent Accesses
<subsec:seals>
In scenarios where the receiver does not trust the sender, there are two attractive options to ensure that the senders cannot modify an RPC buffer while an RPC is in flight: First, the application can copy the RPC buffer, which works well for small objects, but for large and complex objects, it is expensive. For these cases, RPCool provides a faster alternative---sealing the RPC buffer. Seals in RPCool apply to the buffer of an in-flight RPC and prevent the sender from modifying them. The sender uses the new `seal()` system call to seal the RPC and relinquish write access to the buffer when required by the receiver. `librpcool` on the receiver can then verify that the region is sealed by communicating with the sender's kernel over shared memory. If not, `librpcool` would return the RPC with an error.

When the receiver has processed the RPC, it marks the RPC as complete. The sender then calls the `release()` system call, and its kernel verifies that the RPC is complete before releasing the seal.

=== Example RPCool Program
<example-memrpc-program>
#figure(image("../Figures/rpcool/rpcool-api-example-shm.svg"),
  caption: [
    A simple ping-pong server using RPCool. The application requests a buffer and shares data using it. `sendbuf` and `recvbuf` point to the same address. Error handling omitted for brevity.
  ]
)
<fig:code-example-shm>~

@fig:code-example-shm shows the source code for an RPCool-based server and client that communicate over an RPCool channel, `mychannel`. RPCool's interface resembles that of eRPC's, but unlike eRPC, RPCool's RPC buffers are zero-copy. First, the server registers `process()` function (Line 8) that responds to the client's requests with a simple string. Once the function is registered, the server listens for any incoming connections (Line 10).

Similarly, once the client has connected to the server (Line 4), calls the server's function (Line 6). Once the server responds to the request, the client prints the result (Line 9--10).

=== System Details
<system-details>
RPCool's implementation presents several challenges including how to implement sealing efficiently and how to ensure a sender cannot unseal an in-flight RPC. This section details RPCool's system daemon and how RPCool implements sealing.

==== The Daemon and The Kernel
<the-daemon-and-the-kernel>
In RPCool, each server runs a trusted daemon that is responsible for handling all connection and channel-related requests.

The daemon is the only entity in RPCool that makes system calls to map or unmap a connection's heap into a process's address space. Consequently, all application must communicate with the daemon to open and close connections or channels. Although applications are permitted to make `seal()` and `release()` calls, they are not allowed to call `mprotect()` on the connection's heap pages. RPCool's kernel enforces this restriction by allowing only the `release()` system call for the address range corresponding to RPCool's heaps, while blocking all other system calls related to page permissions. This prevents applications from bypassing kernel checks for sealed pages.

==== Sealing Heaps
<sealing-heaps>
RPCool's seal implementation prevents the sender from concurrently modifying an RPC buffer and enables the receiver to verify the seal before processing an RPC. This section describes how RPCool efficiently implements these features.

#BoldParagraph[Seal implementation.]
<seal-implementation.>
RPCool lets the sender enable sealing on a per-call basis and specify the memory region associated with the request. When a sender requests to seal an RPC, `librpcool` calls a purpose-built `seal()` system call. In response, the kernel makes the corresponding pages read-only for the sender and writes a seal descriptor to a sender-read-only region in the shared memory. The receiver proceeds after it checks whether the region is sealed by reading the descriptor.

Once an RPC is processed, the sender calls the new `release()` system call and the kernel checks to ensure the RPC is complete and breaks the seal. The descriptors are implemented as a circular buffer, mapped as read-only for the sender but with read-write access for the receiver. These asymmetric permissions allow only the receiver to mark the descriptor as complete and the sender's kernel to verify that the RPC is completed before releasing the seal.

Further, as an application can have several seal descriptors active at a given point in time, the sender also includes an index into the descriptor buffer along with RPC's arguments.

#figure(image("../Figures/rpcool/sealing-mechanism-new.svg"),
  caption: [
    #strong[Sealing mechanism overview];. The sender sends a sealed RPC, and the receiver process checks the seal and processes it. Once processed, the receiver marks the RPC as completed, and the sender releases the seal.
  ]
)
<fig:sealing-mechanism-overview>~

#BoldParagraph[Example.]
<example.>
@fig:sealing-mechanism-overview illustrates the sealing mechanism. Before sending the RPC, the sender calls the `seal()` system call with the region of the memory to seal. Next, the sender's kernel writes the seal descriptor , followed by locking the corresponding range of pages by marking them as read-only in the sender's address space .

Once sealed, the RPC is sent to the receiver. If the receiver is expecting a sealed RPC, it uses `rpc_call::isSealed()` to read and verify the seal descriptor , and processes the RPC if the seal is valid. After processing the request , the receiver marks the RPC as complete in the descriptor and returns the call. Next, when the sender receives the response, it asks its kernel to release the seal . The kernel verifies that the RPC is complete and releases the region by changing the permissions to read-write for the range of pages associated with the RPC .

#BoldParagraph[Optimizing sealing.]
<optimizing-sealing.>
Repeatedly invoking `seal()` and `release()` incurs significant performance overhead as they manipulate the page table permission bits and evict TLB entries~@amit2020don. To mitigate this, RPCool supports batching `release()` calls for multiple RPC buffers. Batching releases amortize the overhead across an entire batch, resulting in fewer TLB shootdowns. To use batched release, applications requests a buffer with batching enabled, copy in or construct the RPC payload in the buffer, and send a sealed RPC.

Upon the RPC's returns, if the application does not immediately need to modify the RPC buffer, it can opt to release the seal in a batch. Batched releases work best when the application does not need to modify the sealed buffer until the batch is processed. However, if needed, the application can invoke `release()` and release the seal on the RPC buffer. In RPCool, each application independently configures the batch release threshold, with a threshold of 1024 achieving a good balance between performance and resource consumption.

==== Adaptive Busy Waiting
<subsec:busy-wait>
RPCool uses busy waiting to monitor for new RPCs and their completion notifications. However, multiple threads busy waiting for RPCs can lead to excessive CPU utilization. To address this issue, RPCool introduces a brief sleep interval between busy-waiting iterations and can also offload the busy-waiting to a dedicated thread. Specifically, in RPCool, each thread skips sleeping between iterations if the CPU load is less than 20%, sleeps for 5~s when the load is between 20%--30%, and offloads busy-waiting to its dedicated thread if the CPU load exceeds 30%. We observe that this achieves a good balance between CPU usage and performance.

=== Evaluation
<sec:overview-first-eval>
Next, we will look at how RPCool's performance compares against other RPC frameworks using microbenchmarks and two real-world workloads, Memcached and MongoDB. Further, the section evaluates how RPCool with its security features stacks up against traditional RPC frameworks.

#BoldParagraph[Evaluation configuration.]
<evaluation-configuration.>
All experiments in this work were performed on machines with Dual Intel Xeon Silver 4416+ and 256~GiB of memory. RDMA-based experiments use two servers with Mellanox CX-5 NICs. For the TCP experiments, we use the NIC in Ethernet mode, enabling TCP traffic over the RDMA NICs (IPoIB~@ipoib). Unless stated otherwise, all experiments are run on the v6.3.13 of the Linux kernel with adaptive sleep between busy-wait iterations (@subsec:busy-wait).

All experiments are running on the local shared memory with sealing enabled. RPCool-relaxed refers to RPCool with sealing disabled.

#figure(
  caption: [No-op Latency and throughput of MemRPC (CXL, CXL-relaxed, and RDMA), RDMA-based eRPC, failure-resilient
CXL-based ZhangRPC, and gRPC. MemRPC-relaxed is MemRPC with sealing and sandboxing (Section~@sec:overview-third) disabled.],
  table(
      columns: (auto, auto, auto, auto, auto, auto, auto),
      
      // inset: 10pt,
      align: horizon,
      table.header(
        [*Framework*], [*RPCool*], [*RPCool \ Relaxed*], [*RPCool \ (RDMA)*], [*eRPC~@erpc*], [*ZhangRPC \ @zhang2023partial*], [*gRPC~@grpc*]
      ),
      [No-op Latency], [1.5~μs], [0.5~μs], [17.1~μs], [3.3~μs], [9.4~μs], [4.7~ms],
      [Throughput (K req/s)], [654.1], [1748.1], [58.6], [303.0], [105.3], [0.21],
      [Transport], [CXL], [CXL], [RDMA], [RDMA], [CXL], [TCP]
  )
)<tab:overview-noop-rpcs>

#let SideHeader(txt, rows) = {
  table.cell(
    rowspan: rows,
    rotate(
      -90deg, 
      reflow: true, 
      [#par(leading: 0.2em, txt)]
    )
  )
}

#rotate(-90deg, reflow: true, 
{[
  
#show table.cell.where(y: 0): strong
#show table.cell.where(y: 1): strong
#show table.cell.where(x: 0): strong
// #show table.cell: it => par(leading: 1em, it)
#show table.cell: it => text(weight: "bold")[#it]

#figure(
  caption: [Comparison of various MemRPC operations, repeated 2 million times. Data in column RDMA and about sandboxes will
be discussed in Section~@sec:overview-third. Data in column CXL will be discussed in Section~@sec:overview-second. (1k = 1024)],
  rotate(0deg, reflow: true, table(
  columns: 6,
  table.header(
    table.cell(rowspan: 2, ""),
    table.cell(rowspan: 2, align: horizon, "Operation"),
    table.cell(colspan: 3, align: center, "Mean Latency"),
    table.cell(rowspan: 2, align: horizon, "Description"),
    [Local DDR],
    [CXL],
    [RDMA],
  ),
  // 1
  SideHeader([RPCool\ Ops], 6),
  "No-op MemRPC-relaxed RPC",
  "0.5 µs",
  "0.5 µs",
  "17.1 µs",
  "RTT for MemRPC no-op RPC.",

  // 2
  "No-op Sealed RPC (1 page)",
  "1.3 µs",
  "1.4 µs",
  "—",
  "RTT for MemRPC with seal and no sandbox.",

  // 3
  "No-op Sealed+Sandboxed RPC (1 page)",
  "1.5 µs",
  "1.5 µs",
  "—",
  "RTT for MemRPC with seal and a cached sandbox.",

  // 4
  "Create Channel",
  table.cell(colspan: 3, align: center, "18.7 ms"),
  "Channel creation latency",

  // 5
  "Destroy Channel",
  table.cell(colspan: 3, align: center, "26.5 ms"),
  "Channel destruction latency",

  // 6
  "Connect Channel",
  table.cell(colspan: 3, align: center, "0.3 s"),
  "Latency to connect to an existing channel",

  // 7
  SideHeader([Sandbox\ Ops], 4),
    "Cached Sandbox Enter+Exit (1 page)",
    table.cell(colspan: 3, align: center, "89.0 ns"),
    "Enter+exit a sandbox with a single SHM page",

  // 8
    "Cached Sandbox Enter+Exit (1k page)",
    table.cell(colspan: 3, align: center, "73.0 ns"),
    "Enter+exit a sandbox with 1024 SHM pages",

  // 9
    "Cached 8 Sandbox Enter+Exit (1 page)",
    table.cell(colspan: 3, align: center, "78.0 ns"),
    "Enter+exit 8 sandboxes, no prot. key reassignment",

  // 10
    "Uncached 32 Sandbox Enter+Exit (1 page)",
    table.cell(colspan: 3, align: center, "0.6 µs"),
    "Enter+exit 32 sandboxes, needs reassigning prot. keys",

  // 11
  SideHeader([Seal/Release,\ & `memcpy()`], 6),
    "Seal+standard release, no RPC (1 page)",
    table.cell(colspan: 3, align: center, "0.77 ms"),
    "Seal and release a single SHM page (no RPC)",

  // 12
    "Seal+standard release, no RPC (1k page)",
    table.cell(colspan: 3, align: center, "0.92 ms"),
    "Seal and release 1024 SHM pages (no RPC)",

  // 13
    "Seal+batch release, no RPC (1 page)",
    table.cell(colspan: 3, align: center, "0.47 ms"),
    "Seal and release in batch a single SHM page (no RPC)",

  // 14
    "Seal+batch release, no RPC (1k page)",
    table.cell(colspan: 3, align: center, "2.72 ms"),
    "Seal and release in batch 1024 SHM pages (no RPC)",

  // 15
    [node-node `memcpy()` (1 page)],
    [0.98 µs],
    [1.75 µs],
    [2.31 µs],
    [`memcpy()` latency for node to node copy (1 page)],

  // 16
    [node-node `memcpy()` (1k page)],
    [311.9 µs],
    [758.0 µs],
    [368.6 µs],
    [`memcpy()` latency for node to node copy (1024 pages)],
))
)<tab:microbench>


]} ) #pagebreak()~

#BoldParagraph[No-op round trip latency and throughput.]
<no-op-round-trip-latency-and-throughput.>
@tab:overview-noop-rpcs compares RPCool, RPCool-relaxed variants against several RPC frameworks and shows that RPCool significantly outperforms all other RPC frameworks by a wide margin. Unlike RPCool, ZhangRPC attaches an 8-byte header to every CXL object and uses fat pointers for references. ZhangRPC creates and uses these CXL objects for metadata associated with an RPC, slowing down no-op RPCs and operations like constructing a tree data structure as it require creating a CXL object and a fat pointer per tree node. Further, in ZhangRPC, assigning a node as a child requires the programmer to call a special `link_reference()` API, adding overhead on the critical path.

#figure(image("../Figures/rpcool/memcached-ycsb-result.svg"),
  caption: [
    Memcached running the YCSB benchmark. // DSM results are discussed in @par:memcached-mongodb-dsm.
  ]
)
<fig:first-memcached-ycsb>

#figure(image("../Figures/rpcool/mongodb-ycsb-result.svg"),
  caption: [
    MongoDB running the YCSB benchmark. // DSM results discussed in @par:memcached-mongodb-dsm.
  ]
)
<fig:first-mongodb-ycsb>~

#BoldParagraph[RPCool operation latencies.]
<memrpc-operation-latencies.>
Next, we look at the latency of RPCool's features in @tab:microbench. RPCool takes only 0.5~s in relaxed mode, and 1.3~s when using the seal operation.

Using @tab:microbench, we also look at the cost of the `seal()` and `release()` system calls. Overall, when using standard `seal()`+`release()`, RPCool takes 0.77~s, however, using batched `release()`, this drops to 0.47~s as the cost of changing the page table permission is amortized across multiple `seal()` calls.

#BoldParagraph[Memcached.]
<memcached.>
@fig:first-memcached-ycsb shows the execution time of memcached running the YCSB benchmark~@ycsb using Zipfian distribution. RPCool outperforms UNIX domain sockets by at least 8.55$times$. As memcached transfers small amounts of data, it uses `memcpy``()` instead of sealing for isolation.

For each YCSB workload, we load Memcached with 100k keys and run 1 million operations. Since Memcached is a key-value store, it does not support SCAN operations and thus, it cannot run YCSB's E workload~@ycsb-scan.

#BoldParagraph[MongoDB.]
<mongodb.>
@fig:first-mongodb-ycsb compares the execution time of MongoDB using RPCool vs its built-in UNIX domain socket-based communication. Across the workloads, RPCool's local shared-memory implementation outperforms UNIX domain sockets.

Like Memcached, we evaluate MongoDB with 100k keys and 1 million operations for each YCSB workload and do not implement sealing as MongoDB internally copies the non-pointer-rich data it receives from the client.

== Pointer-Rich RPCs
<sec:overview-third>

RPCool supports allocating complex, pointer-rich data structures directly in the shared memory and sharing pointers to them. This unlocks a whole class of use cases for RPCool as applications no longer need to serialize complex data structures in order to share them. In this section, we extend RPCool's interface by exposing portions of its internal mechanism to the application. This improves performance by allowing end-to-end zero-copy RPCs.

Although sharing complex pointer-rich data structures enables powerful new use cases like shared memory databases where the server shares only a pointer to the requested data, RPCool needs to address several challenges: (a) RPCool should ensure that pointer-rich data structures are valid when shared over RPCs, i.e., pointers do not need to be translated, (b) RPCool should extend the mutual exclusion guarantees between the sender and receiver to any data structures shared by the RPC, and (c) RPCool should enable applications to use native pointers without making them vulnerable to wild or invalid pointers.

=== Enabling pointer-rich data structures
<enabling-pointer-rich-data-structures>
To address the challenges of sharing pointer-rich data structures, RPCool extends RPC buffers to support native pointers that are valid across servers. This section details how RPCool supports globally valid pointers within RPC buffers while also providing support for connection-specific shared memory heaps.

#BoldParagraph[Globally valid pointers.]
<globally-valid-pointers.>
To be able to share pointer-rich data, RPCool needs to ensure that the shared memory heaps for each connection is mapped to a unique address across servers in a cluster. RPCool ensures this by using a fixed address for each heap across all machines that are under the control of an orchestrator. When a heap is created, the orchestrator assigns it a globally (in the cluster) unique address where the heap will be mapped in a process's address space. Giving each heap a unique address space ensures that a client or server in cluster can safely map it into its address space.

#BoldParagraph[Augmenting RPC buffers for pointer-rich data structures.]
<augmenting-rpc-buffers-for-pointer-rich-data-structures.>
So far, RPCool provided traditional network-like isolation by sealing the RPC buffer. However, providing similar isolation for pointer-rich data is more challenging as pointer-rich data could be a collection of non-contiguous memory regions making it harder to seal just the object being shared. A naive way of ensuring this isolation would be to let applications to allocate data structures anywhere on the heap, and seal the channel's entire shared memory heap. However, this would make the entire heap, including much unrelated data, unavailable during an RPC.

To address this, RPCool supports allocating complex pointer-rich data structures directly in the RPC buffer where applications can allocate objects and link them together. RPC buffers in RPCool are contiguous sets of pages that hold self-contained data structures. Applications create complex objects in RPC buffers by constructing them directly in the RPC buffer. The sender can thus send an RPC with arguments limited to an RPC buffer, sealing only the data needed for the RPC.

// #heading(level: auto, depth: 3, [#align(left, "Hello")])

RPCool provides a thread-safe memory allocator to allocate/free objects from the shared memory heaps and RPC buffers. Additionally, RPCool provides several STL-like containers such as `memrpc::vector`, `memrpc::string`, etc. These containers enable programmers to use a familiar STL-like interface for allocating objects but do not preclude custom pointer-rich data structures, e.g., trees or linked lists. The allocator and containers are based on Boost.Interprocess~@boost.interprocess. RPCool provides custom data structures since the C++ standard template library makes no guarantees about accessing data structures from multiple processes or from where the memory for internal need is allocated.

#figure(image("../Figures/rpcool/private-public-channel-overview.svg", width: 70%),
  caption: [
    Private and public connections in RPCool.
  ]
)
<fig:private-public-channel-overview>~

#BoldParagraph[Shared memory heaps.]
<shared-memory-heaps.> Each connection in RPCool is associated with a shared memory heap, enabling applications to allocate and share RPC data. RPC buffers for a connection are allocated from the connection's heap. @fig:private-public-channel-overview a--b shows how a single server can serve multiple clients by using independent heaps that are private to each connection (@fig:private-public-channel-overview a) or by using a single shared heap across multiple connections (@fig:private-public-channel-overview b). Connections start with a statically sized heap and can allocate additional heaps if they need more space.

=== Preventing Unsafe Pointer Accesses using Sandboxes
<subsec:sandboxes>
#figure(image("../Figures/rpcool/sandboxing-summary.svg", width: 60%),
  caption: [
    Sandboxing overview.
  ]
)
<fig:sandboxing-summary>~

Sharing complex data structures brings the potential for wild or invalid pointers. To ensure safety, RPCool protects applications from these dangers.

When processing an RPC, the receiver might dereference pointers, that point to an invalid memory location and crash the application, or alternatively, they could point to the receiver's private memory, potentially leaking sensitive information. For example, a malicious sender could exploit this by creating a linked list with its tail node pointing to a secret key within the server, thereby extracting the key from a server that computes some aggregate information about the elements in the list.

RPCool includes support for sandboxes, which prevents invalid or wild pointers from causing invalid (or privacy-violating) memory access as the receiver processes the RPC's arguments (@fig:sandboxing-summary). Sandboxing and sealing are orthogonal and can be applied (or not) to individual RPCs.

Using sandboxes, applications can validate pointers in received RPC data, while sealing ensures that the validated data cannot be modified by the sender while receiver processes it.

When processing a sandboxed RPC, a process enters the sandbox, loses access to its private memory, and has access to only its shared memory heap and a set of programmer-specified variables. If the process tries to access memory outside the sandbox, it receives a signal that the process handles and uses to respond to the RPC.

To minimize the cost of sandboxing incoming RPCs, RPCool relies on Intel's Memory Protection Keys (MPK)~@sung2020intra, avoiding the expensive `mprotect()` system calls. @subsec:sandboxes-impl explains the details of how RPCool's sandboxes work.

We considered using non-standard pointers that enable runtime bound checks, but such pointers would limit compatibility with legacy software, compilers, and debuggers and would have significant performance overheads~@mahar2024puddles.

=== RDMA Fallback
<rdma-fallback>
Shared memory is not always available. While falling back to eRPC is viable for the RPC interface in @sec:overview-first, eRPC cannot handle complex data structures. For these, RPCool provides an optimized RDMA-based software coherence system as a fall back.

The system is a minimal two-node RDMA-based shared memory, avoiding the expensive synchronization of multi-node distributed shared memory (DSM) implementations like ArgoDSM~@argodsm.

Whenever a node writes to a page, it gets exclusive access to the page by unmapping it from all other nodes that have access to it. After the node has updated the page, it can send an RPC to the other compute node, which can then access the page at which RPCool moves the page to the receiver.

=== Example RPCool Program
<example-memrpc-program-1>
#figure(image("../Figures/rpcool/rpcool-api-example.svg", width: 80%),
  caption: [
    A simple ping-pong server using RPCool. The application requests a buffer and shares pointer-rich data using it. Error checking omitted for brevity.
  ]
)
<fig:code-example-app-integrated>
\

@fig:code-example-app-integrated extends the RPCool's previous example (@fig:code-example-shm) to return a pointer to a string instead of copying it into the RPC buffer. Similar to the previous example, once the client has connected to the server (Line 4), it calls the server's function (Line 6). Once the server responds to the request with a pointer to the result, the client prints the result and the pointer of the object received (Line 8--9). As RPCool maps objects at the same address across servers, both the server (line 6) and the client (line 8) will print the same address.

While RPCool enables applications to share complex pointer-rich data structures without serialization, like gRPC and ThriftRPC, RPCool requires the use of custom types for data structures like vectors and strings. For example, to use an array in gRPC, the programmer would use Protobuf schema to declare an array `foo`, compile and link the interfaces with their application, and use methods like `add_foo()` and `foo_size()` to add a new element and check the size of the array, respectively.

=== System Details
<system-details-1>
Integrating pointer-rich RPCs into an application requires support for RPC buffers, sandboxes, and the ability for applications to dynamically allocate and share pointer-rich data over shared memory. This section details how RPCool achieves efficient sandboxing while providing an STL-like interface for object management.

==== Extending RPC Buffers
<subsec:scope-impl>

Applications can allocate new objects in the RPC buffer using the buffer's memory management API or by copying in existing object data.

To create an RPC buffer, the programmer requests a buffer of the desired size from the connection's heap using the `Connection::create_buf(size)` API. RPCool allocates the requested amount of memory from the connection's heap and initializes the buffer's memory allocator. The programmer can then allocate or free objects within the buffer's boundary.

An application can destroy RPC buffers to free the associated memory or reset it to reuse the buffer. Once destroyed or reset, all objects allocated within the buffer are lost.

==== Sandboxes
<subsec:sandboxes-impl>
#figure(image("../Figures/rpcool/sandboxing-working.svg", width: 70%),
  caption: [
    Preallocated sandboxes, their key assignment, and key permissions in RPCool.
  ]
)
<fig:sandbox-working>~

RPCool enables applications to sandbox an RPC by restricting the processing thread's access to any memory outside of an RPC's arguments. This prevents the applications from accidentally dereferencing pointers to private memory. To be useful, RPCool's sandboxes must have low performance overhead, should allow dynamic memory allocations despite restricting access to the process's private memory, and permit selective access to private variables.

#BoldParagraph[Low overhead sandboxes using Intel MPK.]
<low-overhead-sandboxes-using-intel-mpk.>
RPCool uses Intel's Memory Protection Keys (MPK)~@libmpk to restrict access to an application's private memory when in a sandbox, avoiding the much more expensive `mprotect()` system call. To use MPK, a process assigns protection keys to its pages and then sets permissions using the per-cpu `PKRU` register. In MPK, keys are assigned to pages at the process-level, while permissions are set at the thread level. Since MPK permissions are per-thread, they enable support for multiple in-flight RPCs simultaneously. Current Intel processors have 16 keys available.

Once a thread enters a sandbox, it uses Intel MPK to drop access to the process's private memory and any part of the connection's heap except for the sandboxed region. The receiver starts and ends sandboxed execution using the `SB_BEGIN(start_addr, size_bytes)` and `SB_END` APIs. The receiver starts the sandbox with the same address and size as the RPC buffer used for the RPC. However, RPCool also supports sandboxing an arbitrary range of pages within the connection's heap as required by an RPC.

To use Intel's MPK-based permission control, RPCool assigns a key to each region that needs independent access control, as shown in @fig:sandbox-working. RPCool uses one key each for the application's private memory, unsandboxed shared memory regions, and every sandbox. Once a key is assigned to a set of pages, RPCool updates the per-thread `PKRU` register entry to update their permissions.

When an application enters a sandbox, RPCool drops access for all keys except for the one assigned to the sandbox. If the sandboxed thread accesses any memory outside the sandbox, the kernel generates a `SIGSEGV` that the process can choose to propagate to the sender as an error.

#BoldParagraph[Dynamic allocations in sandboxes.]
<dynamic-allocations-in-sandboxes.>
As the sandboxed thread no longer has access to the process's private memory, the thread cannot allocate objects in it. However, the application may need to allocate memory from `libc` using `malloc``()`/`free``()` or invoke a library from within the sandbox that allocates private memory internally.

To address this, RPCool redirects sandboxed `libc` `malloc``()`/`free``()` calls to a temporary heap instead of the process's private heap. After the sandbox exits, data in this temporary heap is lost. However, redirecting memory allocations works only for libraries and other APIs that free their memory before returning and do not maintain any state across calls. To safely use stateful APIs over pointer-rich data, an application can validate the pointers in a sandbox before calling the stateful API outside the sandbox.

#BoldParagraph[Accessing data outside the sandbox.]
<accessing-data-outside-the-sandbox.>
When in a sandbox, an application cannot access the connection's private heap, however, in some cases applications might require access to certain private variables to avoid entering and exiting the sandbox multiple times to service an RPC call. To address this, RPCool supports copying programmer-specified private variables into the sandbox's temporary heap. To copy a private variable, the programmer specifies a list of variables in addition to the region to sandbox when starting a sandbox: `SB_BEGIN(``region,` `var0,` `var1...)`.

To export data generated by a thread inside a sandbox, application can allocate it directly in the buffer for the RPC, and retain access to it after exiting the sandbox.

#BoldParagraph[Optimizing sandboxes.]
<optimizing-sandboxes.>
Although changing permissions using Intel MPK takes tens of nanoseconds, assigning keys to pages has similar overheads as the `mprotect()` system call~@libmpk. To avoid assigning keys to on-demand sandboxes, RPCool reserves up to 14 pre-allocated or #emph[cached] sandboxes of varying sizes with pre-assigned keys. This is limited by the number of protection keys available. RPCool reserves 2 keys for the private heap and unsandboxed regions, respectively. To service a request for an uncached sandbox region, RPCool waits for an existing sandbox to end, if needed, and reuses its key. This enables RPCool to dynamically create sandboxes without being limited to 14 pre-allocated sandboxes, albeit at the cost of reassigning protection keys.

==== RDMA Fallback
<rdma-fallback-1>
RPCool includes support for automatic RDMA fallback for pointer-rich communication that spans shared-memory domains. While applications could use traditional RPC frameworks like ThriftRPC or gRPC to bridge the gap, this leads to additional programming overhead as the programmer needs to pick the API depending on where the target service is running. Moreover, RPCool cannot transparently fall back to an existing RPC system because none of them support sending pointer-based data structures.

RPCool addresses these limitations by implementing a simple RDMA-based shared memory mechanism that is optimized for RPCool's pattern of memory sharing. Where either a server or a client has exclusive access to a shared memory page. When a server attempts to access the data on a page using `load`/`store` instructions, the instruction succeeds if the server has exclusive ownership of the page. If not, the server triggers a page fault, fetches the page from the client, and re-executes the instructions once mapped. Once fetched, the page is marked as unavailable on the client, and it would need to request the page back from the server in order to access the page.

#BoldParagraph[Programming interface.]
<programming-interface.>
RPCool over RDMA supports communication only between one server and one client. Consequently, RPCool also does not support simultaneous access to a heap over both CXL and RDMA. While RPCool over RDMA only supports two-node communication, all other programmer-facing interfaces are identical to RPCool's CXL implementation, e.g., allocating and accessing shared objects.

This limitation exists because when a process wants exclusive access to a page shared over RDMA, RPCool must unmap the corresponding page from all other processes across the datacenter that have access to it, which adds significant performance overheads and system complexity.

To address this limitation, RPCool includes support for deep-copying pointer-rich data structures between connection heaps using the `conn.copy_from(ptr)` API. `copy_from()` automatically traverses a linked data structure using Boost.PFR~@boost.pfr and deep copies to the connection's heap, allowing applications to interoperate between connections of different types without significant programming overhead.

#BoldParagraph[Sealing and sandboxing with RDMA fallback.]
<sealing-and-sandboxing-with-rdma-fallback.>
Sealing and sandboxing for RDMA-based shared memory pages works similarly to RPCool's shared-memory implementation.

When a sender sends a sealed RPC, the corresponding pages are marked as read-only in its address space, preventing any modifications by the sender while the RPC is in-flight. Further, to process an incoming RPC over RDMA fallback, the application can create a sandbox over the RPC's arguments in the same manner as it would for processing an RPC over CXL-based shared memory.

=== Evaluation
<evaluation>
To understand the advantages of integrating RPC with the application, we will look at two applications, CoolDB, a shared memory document store that allows pointer-rich data and a social network website benchmark. Unless noted otherwise, RPCool results are with sealing and sandboxing turned on, while RPCool-relaxed does not turn on sealing or sandboxing. All workloads were evaluated on local shared memory.

#BoldParagraph[RPCool operation latencies.]
<memrpc-operation-latencies.-1>
To understand sandbox latency and its impact on RPCool's performance, we measured the latency of a no-op RPC with sealing and sandboxing at 1.5~s compared to 0.5~s with no sealing or sandboxing. When cached, sandboxes (i.e., sandboxes with pre-assigned protection key) have very low enter+exit latency at 78.0~ns. This latency increases to 0.6~s when the sandbox is not cached and RPCool needs to reassign protection keys and set up the sandbox's heap.

Finally, using @tab:microbench, we look at the latency of `memcpy``()` to compare it against the cost of sealing+sandboxing, which includes sealing a page, starting a sandbox over it, and finally releasing it. This is because applications can copy RPC arguments to prevent concurrent accesses from the sender without using sealing+sandboxing. We observe that on local DRAM, for more than a page, sealing+sandboxing is faster than `memcpy``()` (0.77~s vs 0.98~s). This suggests that for data smaller a page, applications should use `memcpy``()`, while for data larger than a page, applications should use sealing+sandboxing.

#BoldParagraph[Memcached and MongoDB.]
<par:memcached-mongodb-dsm>
To understand how RPCool's DSM performs, we evaluated Memcached (@fig:first-memcached-ycsb) and MongoDB (@fig:first-mongodb-ycsb) against TCP over Infiniband.

For Memcached and MongoDB, RPCool's DSM implementation outperforms TCP over Infiniband by at least 1.93$times$ and 1.34$times$, respectively.

#figure(image("../Figures/rpcool/cooldb.svg", width: 90%),
  caption: [
    RPCool's performance running CoolDB over CXL to showcase worst case performance.
  ]
)
<fig:cooldb-perf>~


#BoldParagraph[CoolDB.]
<cooldb.>
CoolDB is a custom-built JSON document store. Clients store objects in CoolDB by allocating them in the shared memory and passing their references to the database along with a key. CoolDB then takes ownership of the object and associates the object with the key. The clients can read or write to this object by sending CoolDB a read request with the corresponding key. In return, it receives pointer to the in-memory data structure that holds the data.

To evaluate CoolDB, we first populate it with 100k JSON documents using the NoBench load generator~@nobench (labeled "build" in the figures) and then issue 1000 JSON search queries to the database (labeled "search" in the figures).

@fig:cooldb-perf shows the total runtime of the two operations for the three versions of RPCool (RPCool, RPCool-relaxed, and RPCool-RDMA), ZhangRPC, and eRPC. Overall, RPCool outperforms all other RPC frameworks when running over CXL, including Zhang RPC. However, it slows down considerably when running over RDMA during the build phase, as the shared memory needs to copy multiple pages back and forth. Moreover, as RPCool does not need to serialize the dataset or the queries, it considerably outperforms eRPC for the search operation.

While accessing objects stored in CXL memory has additional latency, CoolDB is a replacement for the use case where applications or microservices use dedicated machines as database, e.g., a dedicated server running MongoDB or Memcached. In such cases, the network access latency would eclipse the additional access latency of CXL shared memory.

#figure(image("../Figures/rpcool/tput-vs-lat.svg"),
  caption: [
    DeathStarBench SocialNetwork Benchmark P50 and P90 latencies using ThriftRPC and RPCool (on CXL).
  ]
)
<fig:deathstarbench-tput-vs-lat>~


#BoldParagraph[DeathStarBench's Social Network.]
<deathstarbenchs-social-network.>
We evaluate RPCool using the Social Network benchmark from DeathStarBench~@deathstarbench, which models a social networking website. In our evaluation, we replace all ThriftRPC calls among microservices with RPCool on our CXL platform to showcase worst-case performance. However, as DeathStarBench spawns multiple new threads for each request, it contends for the kernel page table lock with RPCool's `seal()` and `release()` calls. To address the issue, we modify the benchmark to use a thread pool instead of creating new threads for each request in both the ThriftRPC and RPCool versions. Additionally, we modified MongoDB to use RPCool. We run DeathStarBench's benchmark that creates user posts under a range of offered loads and measure the median and P90 latency, as shown in @fig:deathstarbench-tput-vs-lat. The experiment is run for 30~seconds for each data point. The results demonstrate that RPCool (both secure and relaxed versions) and ThriftRPC show similar performance, with RPCool's peak throughput surpassing that of ThriftRPC by 10.0%.

To understand why RPCool performs comparably to Thrift RPC, we looked at where a request spends its time using DeathStarBench's built-in tracing. We found that, on average, about 66% of a request's critical path latency is spent in databases and Nginx, suggesting that DeathStarBench's performance is largely bound by database updates and Nginx.

== RPCool over CXL-Based Shared Memory
<sec:overview-second>

CXL promises to deliver multi-node coherent shared memory. RPCool will be able to work on these systems, but a shared memory RPC system over CXL presents additional challenges.

=== Compute Express Link
<sec:cxl-transport-layer>
CXL 3.0 enables multiple hosts to communicate using fast, byte-addressable, cache-coherent shared memory. CXL-connected hosts will be able to map the same region of shared memory in their address space~@dax-cxl-lpc, where updates using `load`/`store` instructions from one host are visible to all other hosts without explicit communication.

To better understand how an RPC framework can exploit CXL's features, we need to first look into how CXL is expected to be deployed. In this work, we consider the scenario where up to 32 servers, with independent OSs are connected to a single pool of shared memory using CXL. Given the challenges of implementing large-scale coherent memory, we assume that CXL memory sharing will not scale far beyond a single rack. We also expect CXL to coexist with conventional networking (TCP and RDMA). Processes within a rack can communicate over the CXL-based shared memory, avoiding expensive network-based communication but can also communicate over RDMA to overcome CXL's limited range.

=== Challenges
<challenges>
RPCool supports CXL 3.0-based shared memory to enable processes on different hosts to communicate using RPCs. While CXL-based shared memory resembles host-local shared memory, RPCool needs to address the additional challenges of shared memory coordination and failure handling. As shared memory regions are now accessible across hosts and OS domains, RPCool must prevent distributed memory leaks and automatically reclaim memory after failures.

=== Orchestrator
<orchestrator>
As RPCool stores RPC queues and buffers in the shared memory, it needs to track the status of each participant to ensure the if a process crashes, other participants are notified in a timely manner. And if everyone accessing the shared memory region crashes, RPCool cleans up any orphaned resources, avoiding memory leaks. Further, RPCool also needs to ensure that no process can consume all the shared memory resources, ensuring fairness.

When the shared memory was limited to a single host, the RPCool daemon was responsible for garbage collection and allocation fairness. However, with multi-host shared memory, RPCool has a global orchestrator that is shared across all nodes participating in RPCool's network.

To address the challenges associated with multi-host shared memory, RPCool's orchestrator uses managed leases on shared memory and imposes shared memory quotas across CXL-connected hosts.

=== Handling Failures in RPCool
<handling-failures-in-memrpc>
#figure(image("../Figures/rpcool/rpcool-failures.svg", width: 80%),
  caption: [
    #strong[Two possible failure scenarios in RPCool.] (a) Server crash results in an orphaned heap. (b) Client left with heaps after multiple servers crash.
  ]
)
<fig:rpcool-failures>\


RPCool must be able to deal with the two major shared-memory failure scenarios: (a) if a server process that is not talking to any client dies, the heaps associated with it are leaked, as no process manages them anymore (@fig:rpcool-failures a) and (b) when a client application that connects to multiple servers; if one of these servers fails, the client might not free the associated heaps and retain a significant amount of shared memory (@fig:rpcool-failures b), consuming shared resources.

To address these challenges, RPCool uses leases and quotas. Every time a process maps a heap as part of a connection, it receives a lease from the orchestrator. Applications using shared memory heaps periodically renew their leases. When a process fails, the lease expires, and the orchestrator can notify other participants and clean up any orphaned heaps. Upon a failure notification, an application can either continue using the heap to access previously allocated objects or release it if it is no longer needed, freeing up resources.

However, to implement leases and quotas, RPCool must satisfy three important requirements:

The first is process failure notifications. When any of the communicating processes fail, other processes should be notified of the failure. This notification ensures that clients can perform appropriate housekeeping measures to clean up any partial states associated with a failed server.

Second, in the case of a total failure where multiple processes crash, but the memory node is alive, the system must reclaim memory to prevent memory leaks. Third, RPCool needs to handle scenarios where if one or more servers that a client is communicating with crash, the client could continue using the associated heaps, resulting in the client potentially using up a large portion or all of the shared memory.

#BoldParagraph[Leases.]
<leases.>
RPCool notifies applications if the server they are communicating with fails and garbage collects orphaned heaps. RPCool achieves this by requiring a lease every time an application maps a connection's heap. Orchestrator uses these leases to track which processes have failed and can notify other applications sharing the memory regions. RPCool creates a lease for each heap, and `librpcool` periodically and automatically renews the lease while the application is running and using the memory.

If the server for a channel fails, the lease expires and the orchestrator notifies all clients connected to the channel of the failure. The clients can continue to access the heap memory but can no longer use it for communication. They can also close the channel. When the last process accessing the heap closes the connection, the orchestrator reclaims the heap.

#BoldParagraph[Quotas.]
<quotas.>
RPCool supports shared memory quotas to limit applications from mapping a large amount of shared memory into their address space. RPCool's orchestrator enforces this configurable quota at the process level. A heap mapped into multiple processes counts against all of their quotas. If mapping a new heap to a process's address space would exceed its quota, the process would need to close enough existing channels to map the new heap.

=== RPCool's Performance on CXL
<sec:overview-second-eval>
In this section, we will look at the performance of RPCool's CXL based multi-host RPCs and application performance using real CXL 2.0 memory expander. As CXL 3.0 devices are not commercially available, we use a CXL 2.0 ASIC-based memory expander with random access latency of 253.4~ns (compared to 114.9~ns for local DRAM) to map all connection heaps. All other configurations are identical to @sec:overview-first-eval.

Running workloads with RPCool on CXL memory, we observe that workloads that use CXL shared memory solely for communication (e.g., Memcached and MongoDB) do not suffer from the additional access latency of the memory expander. Memcached, MongoDB, and DeathStarBench show a maximum performance reduction of 5.2%, 3.0%, and 1.1%, respectively. The results confirm that the orchestrator needed for enabling CXL-based RPC does not affect RPCool's performance.

However, workloads that store their entire working set on CXL observe higher slowdown. For CoolDB, this reduction is 1.9% and 89.9% for building and searching the database, respectively. Despite this, CoolDB on CXL is still 8.3$times$ and 6.7$times$ faster than eRPC for building and searching the database, respectively.

== Related Work
<sec:rpcool-related>

Some prior works have proposed using RPCs over distributed shared memory. Similar to RPCool, Wang et al.~@wang2021in describe RPCs with references to objects over distributed shared memory. However, since they focus on data-intensive applications, they propose immutable RPC arguments and return values and require trust among the applications. Some works also optimize which application unit uses RPCs; Nu~@ruan2023nu breaks down web applications into proclets that share the same address space among multiple hosts and uses optimized RPCs for communication among them. When proclets are placed on the same machine, they make local function calls, and traditional RPCs otherwise. However, in both cases, proclets need to copy the arguments to the receiver and require mutual trust. Lu et al.~@lu2024serialization improve the performance of serverless functions by implementing `rmap()`, allowing serverless functions to map remote memory, thus avoiding serialization. However, `rmap()` requires mutual trust between the sender and the receiver.

Several other works have looked into using shared memory container communication. Shimmy~@khasgiwale2023shimmy implement message passing among containers with support for fallback to RDMA. Hobson et al.~@hobson2021shared offer an interface similar to RPCool which support for passing complex pointer rich data structures over shared memory, however, they do not address the security concerns of shared memory communication. PipeDevice~@su2022pipedevice offloads inter-container communication to the custom hardware, significantly accelerating it.

Numerous prior studies have explored optimizing the performance of RPC frameworks using RDMA, but they all require serialization and compression, adding performance overheads. HatRPC~@hatrpc uses code hints to optimize Thrift RPC and enables RDMA verbs-based communication, while DaRPC~@darpc implements an optimized RDMA-based custom RPC framework. Kalia et al.~@erpc propose a highly efficient RDMA-based RPC framework called eRPC that outperforms traditional TCP-based RPCs in latency and throughput. Chen et al.~@chen2023remote avoid the overhead of sidecars used in RPC deployment by implementing serialization and sidecar policies as a system service. Sidecars are proxy processes that run alongside the main application for policy enforcement, logging, etc., without modifying the application.

Zhang et al.~@zhang2023partial present a memory management system for CXL-based shared memory. Their implementation provides failure resilience against memory leaks without significant performance overheads. In addition to failure resiliency, Zhang et al. also propose CXL-based shared memory RPCs, which we refer to as Zhang RPC. However, Zhang RPC performs significantly slower compared to RPCool (@tab:overview-noop-rpcs), does not scale beyond a rack, and requires mutual trust among applications. Another CXL-based RPC framework, DmRPC~@zhang2024dmrpc supports RPCs over CXL, however, it requires serialization and mutual trust among processes.

Some works have combined CXL-based shared memory with other communication protocols. CXL over Ethernet~@cxl-over-ethernet uses a host-attached CXL FPGA to transmit CXL.mem requests over Ethernet, enabling host-transparent Ethernet-based remote memory. Rcmp~@rcmp overcomes the limited scalability of CXL-based shared memory by extending it using RDMA. However, similar to `rmap()`, it requires applications to mutually trust each other.

Simpson et al.~@simpson2020securing explore the security challenges of deploying RDMA in the datacenter. The challenges listed in their work, e.g., unauditable writes and concurrency problems, are shared by RPCool and other RDMA-based systems alike. Chang et al.~@chang1998security discuss the performance overhead of untrusted senders, as the receiver would need to validate the received pointers and data types. Similar to RPCool, for single-machine communication, Chang et al. propose zero-copy RPCs by directly reading the sender's buffer in trusted environments. Schmidt et al.~@schmidt1996using propose a shared memory read-mostly RPC design where the clients have unrestricted read access to a server's data over shared memory but make protected and expensive RPCs to update it. Further, since the clients cannot hold locks in the shared memory, they implement a multi-version concurrency control to allow updates to the data while clients are reading them. Schmidt et al.'s solution is orthogonal to RPCool and can be combined with it by ensuring read-only permissions for channels in clients and exporting separate secure channels for updates. ERIM~@vahldiek2019erim uses MPK to isolate sensitive data and to restrict arbitrary code from accessing protected regions. However, unlike RPCool which confines accesses to a shared memory region while processing an RPC, ERIM uses MPK for protecting sensitive data from malicious components. Finally, the new `mseal()` system call in Linux introduces functionality similar to RPCool's `seal()` system call, but makes the mapping permanent and read-only, making it unsuitable for RPCs.

Several prior works, including FaRM~@dragojevic2014farm, RAMCloud~@ramcloud, Carbink~@zhou2022carbink, Hydra~@lee2022hydra, and AIFM~@ruan2020aifm enable distributed shared memory and support varying levels of failure resiliency. However, they require application support for reads and writes and often use non-standard pointers, breaking compatibility with legacy code and adding programming overhead. In contrast, RPCool supports the same `load`/`store` semantics for CXL- and RDMA-based shared memory. Further, while RPCool's RDMA fallback does not implement erasure coding, its design does not preclude such features.

== Conclusion <sec:snapshot-conclude>

This work presents RPCool, a fast, scalable, and secure shared memory RPC framework for the cross-container as well as CXL-enabled world of rack-scale coherent shared memory. While shared memory RPCs are fast, they are vulnerable to invalid/wild pointers and the sender concurrently modifying data with the receiver.

RPCool addresses these challenges by preventing the sender from modifying in-flight data using seals, processing shared data in a low-overhead sandbox to avoid invalid or wild pointers, and automatically falling back to RDMA for scaling beyond a rack. Overall, RPCool either performs comparably or outperforms traditional RPC techniques.

== Acknowledgement

This chapter contains material from "MemRPC: Fast Shared Memory RPC For Containers and CXL," by Suyash Mahar, Ehsan Hajyjasini, Seungjin Lee, Zifeng Zhang, Mingyao Shen, and Steven Swanson, which is under review. The dissertation author is the primary investigator and the first author of this paper.