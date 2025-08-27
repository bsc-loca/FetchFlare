# FetchFlare: An Open-Source Strided Data Prefetcher for High-Performance Cache Hierarchies
This repository contains the RTL design for the FetchFlare module of our core-tile L1D-caches project.

---


## Overview
This project presents FetchFlare, an open-source stride prefetcher for high-performance cache hierarchies. FetchFlare is abale to capture the memory access patterns of the applications, predict their future memory accesses, and issue prefetch requests for them. FetchFlare works at the microarchitecture level, without any software intervention, it can identify positive and negative strides, and it can be configured to adjust its aggressiveness.

---

## Contributions
FetchFlare presents a stride prefetcher for high-performance cache hierarchies, and provide an open-source RTL implementation that can be easily reused and extended. It is integrated in a system that includes teh HPDCache, the Sargantana core and the Openpiton cache hierarchy. All the elements of the system are open-source. It is evaluated using a set of memory-intensive benchmarks. Results show that, compared to a system without prefetching, FetchFlare provides an average speedup of 63%, reduces the miss ratio in the L1D and the L2 caches, and achieves average accuracy, coverage, and timeliness of 86%, 39%, and 99%, respectively.

---
## Hardware Structure
The internal design of FetchFlare consists of several hardware structures, including a Reference Prediction Table (RPT) that identifies the strides, a FIFO queue and an engine arbiter that distribute the strides across the engines, the engines that generate the prefetch request, and a request arbiter that issues the prefetch requests to the L1D cache. Figure shows an scheme of the hardware structures of FetchFlare.



<img width="1212" height="515" alt="Graph_Prf" src="https://github.com/user-attachments/assets/4d8d79bf-2ad7-474e-8880-b4cc27581ee4" />

