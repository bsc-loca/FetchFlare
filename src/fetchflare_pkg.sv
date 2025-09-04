/*
 Copyright 2025 BSC*
*Barcelona Supercomputing Center (BSC)

SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

Licensed under the Solderpad Hardware License v 2.1 (the "License"); you
may not use this file except in compliance with the License, or, at your
option, the Apache License version 2.0. You may obtain a copy of the
License at

https://solderpad.org/licenses/SHL-2.1/

Unless required by applicable law or agreed to in writing, any work
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.
 */
/*
 *  Authors       : Golnaz Korkian, Cesar Fuguet
 *  Creation Date : September, 2023
 *  Description   : Linear Hardware Memory Prefetcher wrapper.
 *  History       :
 */

package fetchflare_pkg;
import hpdcache_pkg::*;

    //  Base address configuration register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [63:6] base_cline;
            logic [5:3]  unused;
            logic        cycle;
            logic        rearm;
            logic        enable;
            } hwpf_stride_base_t;
    //  }}}

    //  Parameters configuration register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [63:48] nblocks;
            logic [47:32] nlines;
            logic [31:0]  stride;
            } hwpf_stride_param_t;
    //  }}}

    //  Throttle configuration register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [31:16] ninflight;
            logic [15:0]  nwait;
            } hwpf_stride_throttle_t;
    //  }}}

    //  Status register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [63:48] unused1;
            logic [47:32] busy;
            logic         free;
            logic [30:20] unused0;
            logic [19:16] free_index;
            logic [15:0]  enabled;
            } hwpf_stride_status_t;
    //  }}}

    `ifndef PREFETCHER_TABLE_SIZE
        `define   PREFETCHER_TABLE_SIZE     32
    `endif

    `ifndef HPDC_PREFETCHER_FIFO
        `define   HPDC_PREFETCHER_FIFO     16
    `endif

    localparam int unsigned LRU_size = $clog2(`PREFETCHER_TABLE_SIZE); 


    typedef enum logic [2:0] {                   
                INITIAL = 3'b000,
                STRIDE_DETECTION = 3'b001,
                HIT1 = 3'b010,
                HIT2 = 3'b011,
                HIT3 = 3'b100,
                PREFETCHING = 3'b101
    }prefetching_mode_t;

//It acts as entry point to the queue, connecting the hardware prefetcher with the prefetching engine's register, 
    typedef struct packed {
                hwpf_stride_base_t              base;
                hwpf_stride_param_t             param;
                hwpf_stride_throttle_t          throttle;
    } prefethcing_engine_entry_t;

endpackage
