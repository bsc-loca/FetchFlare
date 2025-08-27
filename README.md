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

## Methodology
In this work, a set of bare-metal benchmark tests is employed to evaluate the proposed prefetcher. The benchmarks have been compiled using the RISC-V C compiler toolchain. Furthermore, an RTL implementation of the proposed prefetcher has been developed in SystemVerilog. For simulation, we utilized two frameworks: Verilator 4.03 (an open-source, C++-based RTL simulator) and QuestaSim-64 2020 (a proprietary RTL simulator from Siemens). All the results reported in the evaluation have been extracted from simulations using QuestaSim.

## Evaluation
We have evaluated the performance benefits of FetchFlare. Various standard metrics are used to assess the performance benefits, such as speedup, Instructions Per Cycle (IPC), Misses Per Kilo Instruction (MPKI), and miss ratio of the caches. Additionally, key prefetching metrics, including accuracy, coverage, and timeliness, are presented. The results demonstrate that, compared to a baseline system without prefetching, FetchFlare achieves an average performance speedup of 63%, it significantly reduces cache miss ratios in the L1D and the L2 caches, and it demonstrates average accuracy, coverage, and timeliness of 86%, 39%, and 99%, respectively.






