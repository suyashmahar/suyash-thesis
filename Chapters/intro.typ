#import "../macros.typ": *

#let intro = [#h(0.5in)In the past few years, application working set sizes and dataset growth have far outpaced memory systems. This is commonly known as the memory wall~@Danesh_MemoryWall@ai-and-memory-wall.
#Green[Traditional DRAM, while fast, is limited in capacity and is expensive~@weiner2022transparent.] As a result, we now have a range of emerging memory technologies that provide large memory capacities with a byte-addressable interface: Intel's now-discontinued DC-PMM~@optane, CXL-based memory expanders~@cxlmemoryexpander, memory boxes~@cxlmembox, and Memory Semantic SSDs~@samsung-ssd. #Green[These memory technologies aim to bridge the gap between fast DRAM and slower, but higher capacity storage devices, like flash memory.

Let us look at the challenges of these emerging memory technologies in more detail to understand how they can be improved upon.
]


First, these new memory technologies are often significantly more expensive to deploy as they require specialized hardware support, and often have increased operational costs. 
Further, they often require a complete software-rewrite to adapt to their device-specific interfaces.

Second, these memory technologies make compromises and tradeoffs compared to the traditional DRAM-based memory. 
For example, all memory technologies listed above have significantly different performance characteristics compared to DRAM, requiring software modifications to fully exploit the potential of these memories.

Finally, unlike the DRAM's interface that we have been using for decades, and are familiar with, these memory technologies require the programmer to use specialized interfaces to get the most out of them.
For example, programming for non-volatile memory requires programmers to use abstractions like transactions for achieving crash consistency. These interfaces often leave a lot to be desired in terms of their ease of use.

Thus, in this thesis, we propose the need for a set of carefully crafted abstractions to help applications achieve the full potential of these new memory technologies.
To solve these challenges, I will present my three research works.


First, we address the complexity and challenges of achieving crash consistency. 
Persistent memory programming libraries require programmers to use complex transactions and manual annotations for applications to be crash consistent. In contrast, the failure-atomic `msync()` (FAMS)~@failureatomicmsync interface is much simpler as it transparently tracks updates and guarantees that modified data is atomically durable on a call to the failure-atomic variant of `msync()`. However, FAMS suffers from several drawbacks, like the overhead of `msync()` and the write amplification from page-level dirty data tracking.

To address these drawbacks while preserving the advantages of FAMS, we propose Snapshot in @chapter:snapshot, an efficient userspace implementation of FAMS.
Snapshot uses compiler-based annotations to transparently track updates in userspace and syncs them with the backing byte-addressable storage copy on a call to `msync()`. By keeping a copy of application data in DRAM, Snapshot improves access latency. Moreover, with automatic tracking and syncing changes only on a call to `msync()`, Snapshot provides crash-consistency guarantees, unlike the POSIX `msync()` system call.

While snapshot makes crash consistency on non-volatile memory devices easier for the programmer, they still have to rely on traditional memory or block-storage interfaces to access it. In @chapter:puddles we reimagine the persistent memory programming interfaces and solve the major challenges with interfaces available today using puddles.

We argue that current work has failed to provide a comprehensive and maintainable in-memory representation for persistent memory.
PM data should be easily mappable into a process address space, shareable across processes, shippable between machines, consistent after a crash, and accessible to legacy code with fast, efficient pointers as first-class abstractions.
While existing systems have provided niceties like `mmap()`-based load/store access, they have not been able to support all these necessary properties due to conflicting requirements.

We propose Puddles, a new persistent memory abstraction, to solve these problems. Puddles provide application-independent recovery after a power outage; they make recovery from a system failure a system-level property of the stored data, rather than the responsibility of the programs that access it. Puddles use native pointers, so they are compatible with existing code. Finally, Puddles implement support for sharing and shipping of PM data between processes and systems without expensive serialization and deserialization.

Finally, in @chapter:rpcool, we take a new approach to the shared memory technology and build a high-performance RPC framework on top of CXL-based shared memory. Datacenter applications often rely on remote procedure calls (RPCs) for fast, efficient, and secure communication. However, RPCs are slow, inefficient, and hard to use as they require expensive serialization and compression to communicate over a packetized serial network link. Compute Express Link 3.0 (CXL) offers an alternative solution, allowing applications to share data using a cache-coherent, shared-memory interface across clusters of machines.

RPCool is a new framework that exploits CXL's shared memory capabilities. RPCool avoids serialization by passing pointers to data structures in shared memory. While avoiding serialization is useful, directly sharing pointer-rich data eliminates the isolation that copying data over traditional networks provides, leaving the receiver vulnerable to invalid pointers and concurrent updates to shared data by the sender. RPCool restores this safety with careful and efficient management of memory permissions. Another significant challenge with CXL shared memory capabilities is that they are unlikely to scale to an entire datacenter. RPCool addresses this by falling back to RDMA-based communication. Finally, @chapter:conclude concludes the thesis.

The introduction contains material from: "Snapshot: Fast, Userspace Crash Consistency for CXL and PM Using msync," by Suyash Mahar, Mingyao Shen, Terence Kelly, and Steven Swanson, which appears in the Proceedings of the 41st IEEE International Conference on Computer Design (ICCD 2023) of which the dissertation author is the primary investigator and first author. "Puddles: Application-Independent Recovery and Location-Independent Data for Persistent Memory," by Suyash Mahar, Mingyao Shen, TJ Smith, Joseph Izraelevitz, and Steven Swanson, which appears in the Proceedings of the 19th European Conference on Computer Systems (EuroSys 2024)  of which the dissertation author is the primary investigator and first author. "MemRPC: Fast Shared Memory RPC For Containers and CXL," by Suyash Mahar, Ehsan Hajyjasini, Seungjin Lee, Zifeng Zhang, Mingyao Shen, and Steven Swanson, which is under review of which the dissertation author is the primary investigator and co-first author. 

]

#intro