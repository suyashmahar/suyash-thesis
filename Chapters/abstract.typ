#import "../macros.typ": *

#let abstract = [
  Several new memory technologies have emerged in the recent past to address the growing need for memory capacity and bandwidth. These memory technologies include Intel 3D X-Point-based DC-PMM and CXL-based memory expanders, memory semantic SSDs, and shared memory pools. However, these new memory technologies are significantly more expensive to deploy as they require specialized hardware and software support. Using these memory technologies requires new programming methodologies, however, they are often supported using legacy memory or storage interfaces.
  
  To solve these challenges, in thesis, we focus on three different aspects to better utilize these new memory technologies. First, we adapt existing storage interface for newer non-volatile memories using Snapshot. Next, with Puddles, we reimagine the interface for accessing high-performance, byte-addressable non-volatile memories. Finally, we explore how to use upcoming Compute Express Link (CXL)-based shared memory to build high-performance RPC framework.

  Crash consistent programming for persistent memory is challenging as frameworks available today require programmers to use transactions and manual annotations. While the failure atomic `msync()` (FAMS) presents a simpler interface for crash-consistency by holding off writes to the backing media until the application calls `msync()`, it suffers from significant performance overheads. To overcome these limitations, we propose Snapshot, a userspace implementation of FAMS. Snapshot uses compiler-based annotations to efficiently track and sync updates to the backing media on a call to `msync()`. Snapshot offers between 1.2$times$ to 8$times$ better performance than PMDK across a range of workloads and evaluation platforms.

  While Snapshot is able to significantly improve application performance while using the legacy interface, applications are still limited by their idiosyncrasies. Interfaces available are limited in one or more of their abilities. For example, no persistent memory programming framework enables application to easily map PM data into its address space while being able to share data between process, ship data between machines, and have it be consistent after a crash, and use native, 64-bit pointers. To support these features, we propose Puddles, a new persistent memory abstraction. Puddles provide application independent recovery after a crash, even before the application writing the last time to the data has started again. Puddles support native pointers and are thus compatible with legacy software, all while supporting sharing and shipping PM data between processes and machines without expensive serialization and deserialization.

  Lastly, using RPCool, we show how these emerging memory technologies provide new use cases like high-performance shared memory remote procedure calls (RPCs) using CXL 3.0-based shared memory. Today, datacenters often rely on 
  RPCs for inter-microservice communication. However, RPCs require slow and inefficient serialization and compression to communication over a serial network link like TCP. To address these limitations, we propose RPCool, an RPC framework that uses shared memory to pass pointers to data and avoid serialization. In addition to providing high-performance shared memory RPCs, RPCool also provide isolation similar to traditional networking by preventing invalid pointers and preventing sender from manipulating shared data while the receiver is processing it. Further, to overcome limited range of CXL 3.0, RPCool can automatically fallback to RDMA-based distributed shared memory. Overall, RPCool reduces round-trip latency by 2.2$times$ compared to the state-of-the-art RDMA framework, and 6.3$times$ compared to CXL-based RPC framework. 
]