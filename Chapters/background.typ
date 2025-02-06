#import "../macros.typ": *

To understand the different memory technologies available today to overcome the memory wall, this chapter first provides an overview of byte-addressable devices and then provides the details of non-volatile memories like Intel's DC-PMM and finally the CXL interconnect and device types enabled using it.


== Byte-addressable Storage Devices


Recent advances in memory technology and device architecture have enabled a variety of storage devices that support byte-addressable persistence. These devices communicate with the host using interfaces like CXL.mem~@cxl2, DDR-T~@aepperf, or DDR-4~@nv-dimm and rely on flash, 3D-XPoint, or DRAM as their backing media, as shown in @fig:persistent-mem-devices.

#figure(
  caption: [Byte-addressable devices.],
  placement: bottom,
  table(
    columns: (auto, auto, auto),
    // inset: 10pt,
    align: horizon,
    table.header(
      [*Device*], [*Interface*], [*Technology*]
    ),
    [Optane PM], [Mem. Bus], [PM & Internal caches~@wang2023nvleak],
    [Mem. Semantic SSDs~@samsung-ssd], [CXL 1.0+], [Flash + Large DRAM cache],
    [Memory Expander~@cxlmemoryexpander], [CXL 1.0+], [DRAM],
    [Memory Box~@cxlmembox], [CXL 2.0+], [DRAM],
    [NV-DIMMs~@nv-dimm], [Mem. Bus], [DRAM],
    [Embedded NVM~@reram-soc], [Internal Bus], [ReRAM]
  )
)<fig:persistent-mem-devices>

These devices share a few common characteristics: (1) they offer byte-level access to data, (2) they improve on existing DDR-based memory either in storage capacity, bandwidth, or are non-volatile, and (3) they are generally slower than DRAM. // Later, in @snapshot-overview, we will explain how Snapshot takes advantage of these properties of emerging memories to implement a fast, userspace-based `msync()`.

== Non-Volatile Memory (NVM)

Non-volatile memory, like a disk, does not lose data on a
power failure. However, unlike disks, non-volatile memories are byte-addressable which allows the applications to access them using the processor's load-store interface just like how they would access traditional DDR-based memory.

Examples of non-volatile memories include Intel's DC Persistent Memory Modules~@optane and embedded NVMs~@reram-soc


=== Non-Volatile Memory Programming 
While accessing non-volatile memory using the load-store interface resembles DDR-based memories, ensuring data is consistent after an unexpecting power loss requires programmers to use  a much more complex programming interface.

This is because, when an application issues a store to Persistent Memory, the CPU might buffer the data in its caches, preventing it from reaching the Persistent Memory media. Thus, data written to the Persistent Memory is not guaranteed to reach the persistent media unless explicitly flushed from the caches. To solve this problem, Intel
and other CPU vendors have introduced special CPU instructions that flush the data from volatile caches into the non-volatile domain. On x86, the `clwb`
instruction writes back a cacheline from the CPU caches, and an `sfence` instruction enforces ordering among `clwb` instructions ~@guide2011intel. Other platforms, e.g., ARM, #Green[have] similar instructions (`DC CVAP` and `DSB`) #Green[that ensure] the data has reached the persistence
domain~@holdings2019arm.

#figure(
  image("../Figures/Background/code-example-PM-plain.svg", width: 80%),
  caption: [Code example showing a push function for a linked list data structure. The function in (a) will have inconsistent memory state after a crash between lines 8 and 9 (shown with a lightning bolt), (b) is a crash consistent program using crash-consistent transactions.],
)<fig:bg-code-example-PM-volatile>\

Using these instructions requires the programmer to carefully order
the instructions to ensure the data on the Persistent Memory is always
in a consistent state. Consider an example where the application needs
to insert a new node to the head of a persistent linked list. As shown
in @fig:bg-code-example-PM-volatile#{}a, the application would first
construct a new node on the PM (line 2), set the node as the head
(line 8), and finally increment the node count (line 9). If the system
crashes between the line 8 and 9, on restart, the linked list is in an
inconsistent state. Since the program did not write the new length to
the memory, the length field after restart is off by one. To solve
this problem, the application can roll back the allocation on line 2
and the update on line 8. Rolling back these changes makes the node
count consistent with the actual number of nodes in the linked list.

To simplify ordering requirements for PM, libraries such as Intel's
PMDK provide a transactional syntax, marked by `TX_BEGIN` and
`TX_END`. All updates performed in a transactions are atomic
with respect a crash. That is, if the application crashes during a
transaction, either all or none of the updates will surivive the
crash. @fig:bg-code-example-PM-volatile#{}b implements the same linked
list, but uses PMDK to first backup all the data modified using
`TX_ADD` in the transaction (line 4 and 5) before updating
them. In case the system crashes during transaction, the application
would undo all changes on restart. This is referred to as
undo-logging.
Similarly, an application might choose to use
redo-logging, where it will log the new values for the logged
locations and hold-off the actual updates until the end of the transaction.

#Green[Tracking which updates of a transaction were persisted before a failure is expensive. To avoid this, an application recovering from a crash using undo or redo logging would process every entry in the log. In the case of undo logging, this results in the transaction being completely rolled back, while in case of redo logging, the recovery completes the transaction by reapplying the entries from a redo log.]


== Compute Express Link (CXL)

Compute Express Link (CXL) is a new PCIe-based interconnect that enables novel
host-device, device-device and host-host communications at byte granularity. CXL
enables several use cases like memory expansion and memory sharing while
enabling cache coherent connection among CXL-connected devices and hosts.

=== Protocols

CXL is built on-top of the PCIe physical layer and supports three access protocols for different use case: CXL.io, CXL.cache, and CXL.mem. 

1. *CXL.io* is a PCIe-compatible protocol for discovery, configuration, management, and PCIe IO transactions. CXL.io accesses do not rely on hardware-based cache coherency.

2. *CXL.cache* provides support for CXL devices to coherently access and cache host memory on device. This enables CXL-connected devices to access cached host memory with low-latency compared to PCIe IO transactions or DMAs. #Green[CXL's cache coherency allows CPU cores from multiple hosts or devices to access updated cachelines without explicit software synchronization, similar to how updates from one CPU core in a multiprocessor are visible to other CPU cores.]

3. *CXL.mem* provides support for host to coherently access and cache device memory.

=== Device Types
Using a combination of CXL protocols, CXL defines three device types in its specification (@fig:cxl-device-types).

#place(top, float: true, [#figure(
  caption: [CXL device types.],
  image("../Figures/Background/cxl-device-types.svg", width: 80%)
)<fig:cxl-device-types>])


1. *CXL Type 1*: CXL Type 1 devices are typically accelerators which use CXL.io and CXL.cache to cache host memories. Hosts offload workload to the device and the device can coherently access data directly from the host's memory and process it.

2. *CXL Type 2*: CXL Type 2 devices are accelerators with on-device memory which uses CXL.io, CXL.cache, and CXL.mem, allowing the device to cache host memory locally on the accelerator without requiring explicit copies between host and device.

3. *CXL Type 3*: CXL Type 3 device uses CXL.io and CXL.mem to enable hosts to expand memory capacity or bandwidth using a CXL-attached memory expander.

=== Memory Sharing


#figure(
  caption: [CXL shared memory scenarios.],
  image("../Figures/Background/CXL-scenario-thesis.svg", width: 80%)
) <fig:bg-cxl-shared-memory>\

Using CXL 3.0+, multiple hosts can can connect to the same CXL-attached memory expander or pool. This enables multiple hosts to share the same region of memory and access it coherently without explicit software-based synchonization.

@fig:bg-cxl-shared-memory shows an example of how CXL 3.0-based shared memory could be deployed in a datacenter. A small collection of hosts (a pod) are connected using CXL 3.0 and can access a shared region of memory, while beyond a pod, hosts communicate over traditional networks like RDMA.