#import "../macros.typ": *

#let abstract = [
  Several new memory technologies like Persistent Memory (PM) and Compute Express Link (CXL)-based memories have emerged in the recent past to address the growing need for memory capacity and bandwidth.  
  However, these memory technologies require new programming methodologies and are often supported using legacy memory or storage interfaces.  
  To solve these challenges, first, using Snapshot, we adapt an existing storage interface for newer CXL/PM devices. Next, with Puddles, we reimagine the interface for accessing high-performance, byte-addressable non-volatile memories. Finally, we explore how to use upcoming CXL-based shared memory to build a high-performance RPC framework.
 

  Crash-consistent programming for PM is challenging as frameworks available today require programmers to use transactions and manual annotations. While the failure atomic `msync()` (FAMS) presents a simpler interface for crash-consistency by holding off writes to the backing media until the application calls `msync()`, it suffers from significant performance overheads. To overcome these limitations, we propose Snapshot, a userspace implementation of FAMS. Snapshot uses compiler-based annotations to efficiently track and sync updates to the backing media on a call to `msync()`. 

  While Snapshot is able to significantly improve application performance while using the legacy interface, applications are still limited by their idiosyncrasies. For example, no PM  framework enables applications to easily map PM data into their address spaces while being able to share data between processes and have it be consistent after a crash, or, use native, 64-bit pointers. To support these features, we propose Puddles, a new PM abstraction that provides application-independent recovery after a crash. Puddles support native pointers  all while supporting sharing and shipping PM data between processes and machines without expensive serialization and deserialization.

  Lastly, using RPCool, we show how CXL-based shared memory provides new use cases like high-performance RPCs. RPCs today require slow and inefficient serialization and compression to communication over networks like TCP. To address these limitations, we propose RPCool, an RPC framework that uses shared memory to pass pointers to data and avoid serialization. Additionally, RPCool provides isolation similar to traditional networking by preventing invalid pointers and preventing the sender from manipulating shared data for inflight RPCs. // Further, to overcome limited range of CXL 3.0, RPCool can automatically fallback to RDMA-based distributed shared memory. // Overall, RPCool reduces round-trip latency by 2.2$times$ compared to the state-of-the-art RDMA framework, and 6.3$times$ compared to CXL-based RPC framework. 
]

