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
module fetchflare_wrapper
import fetchflare_pkg::*;
import hpdcache_pkg::*;

//  Parameters
//  {{{
#(
    parameter int unsigned NUM_HW_PREFETCH = 4,
    parameter int unsigned NUM_SNOOP_PORTS = 1,
    parameter int unsigned CACHE_LINE_BYTES = 64,

    //  Request Interface Definitions
    //  {{{
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_set_t = logic,
    //  }}}

    localparam int unsigned INDEX_WIDTH = $bits(hpdcache_req_offset_t),
    localparam int unsigned BLOCK_OFFSET_WIDTH = $clog2(64),
    localparam int unsigned TAG_WIDTH = $bits(hpdcache_tag_t),
    localparam int unsigned ADDR_WIDTH = INDEX_WIDTH + TAG_WIDTH,
    localparam type hpdcache_req_addr_t = logic [INDEX_WIDTH+TAG_WIDTH-1 : 0]
)
//  }}}

//  Ports
//  {{{
(
    input  logic                                        clk_i,
    input  logic                                        rst_ni,
   
    //  CSR
    //  {{{
    output hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0]  hwpf_stride_base_o,
    input  logic                                         hpdc_valid_i,
    input  logic                  [15:0]                 hpdc_prefetcher_cachelines_i,          
    input  logic                  [15:0]                 hpdc_prefetcher_inflight_i,
    input  logic                  [15:0]                 hpdc_prefetcher_wait_i,
    input  logic                  [12:0]                 hpdc_prefetcher_page_size_i,
   
    //  }}}

    // Snooping
    //  {{{
    input  logic                 [NUM_SNOOP_PORTS-1:0] snoop_valid_i,
    input  hpdcache_req_addr_t   [NUM_SNOOP_PORTS-1:0] snoop_addr_i,   
   

    //  Dcache interface
    //  {{{
    input  hpdcache_req_sid_t                           hpdcache_req_sid_i,
    output logic                                        hpdcache_req_valid_o,
    input  logic                                        hpdcache_req_ready_i,
    output hpdcache_req_t                               hpdcache_req_o,
    input  logic                                        hpdcache_rsp_valid_i,
    input  hpdcache_rsp_t                               hpdcache_rsp_i
    //  }}}
);
//  }}}

    //  Internal Types
    //  {{{
    typedef struct packed {
                logic                  valid;
                hpdcache_tag_t         tag;
                prefetching_mode_t     training_mode;
                hpdcache_req_offset_t  index;
                hpdcache_req_offset_t  stride;
                logic [LRU_size - 1:0] LRU_state;
    } prefethcing_table_entry_t;
    //  }}}

    //  Internal signals
    //  {{{
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_enable;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_free;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_status_busy;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_status_free_idx;

    logic            [NUM_HW_PREFETCH-1:0] hwpf_snoop_match;      

    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_req_valid;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_req_ready;
    hpdcache_req_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_req;

    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_req_valid;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_req_ready;
    hpdcache_req_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_req;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_rsp_valid;
    hpdcache_rsp_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_rsp;
    //  }}}

    logic                 [NUM_HW_PREFETCH-1:0] hwpf_stride_base_set_p, hwpf_stride_base_set_p_next; 
    hwpf_stride_base_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_base_p, hwpf_stride_base_p_next;     
    
    logic                 [NUM_HW_PREFETCH-1:0] hwpf_stride_param_set_p, hwpf_stride_param_set_p_next; 
    hwpf_stride_param_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_param_p, hwpf_stride_param_p_next;     
    
    logic                    [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_set_p, hwpf_stride_throttle_set_p_next; 
    hwpf_stride_throttle_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_p, hwpf_stride_throttle_p_next;     
    hpdcache_nline_t         [NUM_HW_PREFETCH-1:0] engines_monitor, engines_monitor_reg;
    
    hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base;  
    hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param; 
    hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle;
    hwpf_stride_status_t                          hwpf_stride_status;

    logic          [NUM_HW_PREFETCH-1:0] arb_prf;
    logic          sign_stride, sign_stride_input;
    
    //{{{

    logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_base_set_internal;     
    hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_internal;  
    hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_internal_monitor;         
    
    logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_param_set_internal; 
    hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param_internal;        
    
    logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_set_internal;  
    hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_internal;     

    logic near_full;
    //}}}

    localparam     [INDEX_WIDTH-1:0] PREF_INDEX = {{(INDEX_WIDTH){1'b0}}};
    localparam     [ADDR_WIDTH-1:0 ] PREF_PA_INDEX = {{(ADDR_WIDTH-(INDEX_WIDTH)){1'b1}},PREF_INDEX}; 
     
    parameter int unsigned SIZE_TABLE = $clog2(`PREFETCHER_TABLE_SIZE);

    //CSR Registers
    logic   [15:0]  hpdc_prefetcher_cachelines_r;          
    logic   [15:0]  hpdc_prefetcher_inflight_r;
    logic   [15:0]  hpdc_prefetcher_wait_r;
    logic   [12:0]  hpdc_prefetcher_page_size_r;    
    logic           engine_rst_n;

//*************************************
    //  Assertions
    //  {{{
    //  pragma translate_off
    initial
    begin
        max_hwpf_stride_assert: assert (NUM_HW_PREFETCH <= 16) else
                $error("hwpf_stride: maximum number of HW prefetchers is 16");
    end
    //  pragma translate_on
    //  }}}

//**********************************************************************************************************
    always @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            hpdc_prefetcher_cachelines_r        <= 16'h8;         
            hpdc_prefetcher_inflight_r          <= 16'h1; 
            hpdc_prefetcher_wait_r              <= 16'h0; 
            engine_rst_n                        <= 1'b0;
        end else begin
            engine_rst_n <= 1'b1;
            if(hpdc_valid_i) begin
                engine_rst_n                    <= 1'b0;
                hpdc_prefetcher_cachelines_r    <= hpdc_prefetcher_cachelines_i;          
                hpdc_prefetcher_inflight_r      <= hpdc_prefetcher_inflight_i;
                hpdc_prefetcher_wait_r          <= hpdc_prefetcher_wait_i;
            end
        end
    end  
//************************************************************************************************************

always @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            hpdc_prefetcher_page_size_r        <= 13'h1000;         
        end else if(hpdc_valid_i) 
            hpdc_prefetcher_page_size_r        <= hpdc_prefetcher_page_size_i;
end  
//***********************************************************************************************************
    //  Compute the status information
    //  {{{
always_comb begin: hwpf_stride_priority_encoder
    hwpf_stride_status_free_idx = '0;
    for (int unsigned i = 0; i < NUM_HW_PREFETCH; i++) begin
        if (hwpf_stride_free[i]) begin
            hwpf_stride_status_free_idx = i;
            break;
        end
    end
end
//**********************************************************************************************************

//     Free flag of engines
    assign hwpf_stride_free            = ~(hwpf_stride_enable | hwpf_stride_status_busy); 
    //     Busy flags
    assign hwpf_stride_status[63:32] = {{32-NUM_HW_PREFETCH{1'b0}}, hwpf_stride_status_busy};
    //     Global free flag
    assign hwpf_stride_status[31]    = |hwpf_stride_free;
    //     Free Index
    assign hwpf_stride_status[30:16] = {11'b0, hwpf_stride_status_free_idx};
    //     Enable flags
    assign hwpf_stride_status[15:0]  = {{16-NUM_HW_PREFETCH{1'b0}}, hwpf_stride_enable};
    //  }}}

//    Calculating the number of the cachelines in each page memory
    logic [15:0]   num_cacheline_page; 
    localparam HPDC_WORD_WIDTH_LOG2 = $clog2(CACHE_LINE_BYTES);
    assign num_cacheline_page = hpdc_prefetcher_page_size_r >> HPDC_WORD_WIDTH_LOG2;  


    prefethcing_table_entry_t  [`PREFETCHER_TABLE_SIZE-1:0]   prefetcher_lut,  prefetcher_lut_next; 
    prefethcing_engine_entry_t                                snooping_entry,  hwpf_fifo_out, temp_fifo_out;
    logic                                                     hwpf_fifo_write, hwpf_fifo_full, hwpf_fifo_empty;
    logic [NUM_HW_PREFETCH-1:0]               hwpf_fifo_read;
    logic [$clog2(`HPDC_PREFETCHER_FIFO)-1:0]  wraddr, rdaddr; 

    
    logic   [NUM_HW_PREFETCH - 1:0] request_enable; 
    logic   [SIZE_TABLE - 1:0]       matched_index; 
    logic                            matched_index_valid;         
    
        
///////////////////////// This logic is used to reset the table ///////////////////////////////////

for (genvar i=0; i<`PREFETCHER_TABLE_SIZE ; i++) begin:LUT_Table     
    always @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            prefetcher_lut[i].valid <= '0;
            prefetcher_lut[i].LRU_state <= i;   
            prefetcher_lut[i].training_mode <= INITIAL;
            prefetcher_lut[i].index <= '0;
            prefetcher_lut[i].tag   <= '0;     
            prefetcher_lut[i].stride   <= '0;   
        end else begin
            prefetcher_lut[i].valid <= prefetcher_lut_next[i].valid;
            prefetcher_lut[i].LRU_state <= prefetcher_lut_next[i].LRU_state ;     
            prefetcher_lut[i].training_mode <= prefetcher_lut_next[i].training_mode;
            prefetcher_lut[i].index <= prefetcher_lut_next[i].index;
            prefetcher_lut[i].tag   <= prefetcher_lut_next[i].tag;     
            prefetcher_lut[i].stride   <= prefetcher_lut_next[i].stride;  
        end
    end  
end 

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

prefetching_mode_t current_training_mode;
prefethcing_table_entry_t current_tag;
assign  current_training_mode = prefetcher_lut[matched_index].training_mode;
assign  current_tag.tag           = prefetcher_lut[matched_index].tag;

always_comb   begin                                               
    matched_index_valid = 0;
    matched_index = 0;
    for (int i = 0; i < `PREFETCHER_TABLE_SIZE ; i++ ) begin //Match Detection
        if(snoop_valid_i && (prefetcher_lut[i].valid) && (prefetcher_lut[i].tag == snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : INDEX_WIDTH])) begin 
           matched_index = i;                                                                                                                               
           matched_index_valid = 1'b1;   
           break;                        
        end 
    end 
end
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

always_comb   begin //Checking the Stride is positive or negative                                         
    sign_stride = 0;
    for (int i = 0; i < `PREFETCHER_TABLE_SIZE ; i++ ) begin 
        if(snoop_valid_i && (prefetcher_lut[i].valid) && ((prefetcher_lut[i].training_mode == HIT3) || (prefetcher_lut[i].training_mode == PREFETCHING))) begin  
            if (snoop_addr_i[0][INDEX_WIDTH - 1:0] < prefetcher_lut[matched_index].index) 
                sign_stride = 1'b1;
            break;
        end 
    end 
end
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

logic   [SIZE_TABLE - 1:0]      fill_index;
logic                           fill_index_valid;
always_comb begin 
    fill_index_valid = 0;
    fill_index = 0;    
    for (int i=0; i< `PREFETCHER_TABLE_SIZE; ++i) begin //Finding Invalid Entry
        if(snoop_valid_i && ~prefetcher_lut[i].valid) begin                                           
          fill_index_valid = 1'b1; 
          fill_index = i;  
          break; 
        end
    end
end
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

logic   [SIZE_TABLE - 1:0]      replace_index;
logic   replace_index_valid;

always_comb begin 
    replace_index_valid = 0;
    replace_index = 0;    
    for (int i=0; i< `PREFETCHER_TABLE_SIZE; ++i) begin 
        if(snoop_valid_i && (prefetcher_lut[i].LRU_state == '1)) begin 
          replace_index_valid = 1'b1;
          replace_index = i;                                                                      
        end 
    end
end                      
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

function automatic logic[4:0] my_log2(input logic[31:0] in);
        automatic logic[4:0] out;
       // out=0;
        logic cnt;
        cnt = (in & in-1) ? 1:0;
        out=0;
        for(int k=0; k<32;k++)begin
            if(in[k]) begin 
                out = k;
            end
        end

        return out+cnt;

endfunction
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

always_comb                                                  
begin : Match 
    prefetcher_lut_next =  prefetcher_lut;
    hwpf_fifo_write = 0;
    if (snoop_valid_i[0]) begin                           
        if(matched_index_valid) begin 
            prefetcher_lut_next[matched_index].LRU_state = '0; 
            case (current_training_mode)
                INITIAL: begin
                    prefetcher_lut_next[matched_index].stride = snoop_addr_i[0][INDEX_WIDTH - 1:0] - prefetcher_lut[matched_index].index;
                    prefetcher_lut_next[matched_index].index  = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                    prefetcher_lut_next[matched_index].training_mode = STRIDE_DETECTION;
                    for (int k = 0; k < `PREFETCHER_TABLE_SIZE; k++) begin 
                        if (prefetcher_lut[k].LRU_state < prefetcher_lut[matched_index].LRU_state) begin
                            prefetcher_lut_next[k].LRU_state++;
                        end
                    end 
                end 
                STRIDE_DETECTION: begin
                    if (prefetcher_lut[matched_index].stride + prefetcher_lut[matched_index].index == snoop_addr_i[0][INDEX_WIDTH - 1:0]) begin
                        prefetcher_lut_next[matched_index].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                        prefetcher_lut_next[matched_index].training_mode = HIT1;
                    end 
                    else begin
                        prefetcher_lut_next[matched_index].stride = snoop_addr_i[0][INDEX_WIDTH - 1:0] - prefetcher_lut[matched_index].index;
                        prefetcher_lut_next[matched_index].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                        prefetcher_lut_next[matched_index].training_mode = INITIAL;
                    end 
                    for (int k = 0; k < `PREFETCHER_TABLE_SIZE; k++) begin 
                        if (prefetcher_lut[k].LRU_state < prefetcher_lut[matched_index].LRU_state) begin
                            prefetcher_lut_next[k].LRU_state++;
                        end
                    end 
                end
                HIT1: begin
                    if (prefetcher_lut[matched_index].stride + prefetcher_lut[matched_index].index == snoop_addr_i[0][INDEX_WIDTH - 1:0]) begin
                        prefetcher_lut_next[matched_index].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                        prefetcher_lut_next[matched_index].training_mode = HIT2;
                    end else begin
                        prefetcher_lut_next[matched_index].stride = snoop_addr_i[0][INDEX_WIDTH - 1:0] - prefetcher_lut[matched_index].index;
                        prefetcher_lut_next[matched_index].index  = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                        prefetcher_lut_next[matched_index].training_mode = INITIAL;
                    end
                    for (int k = 0; k < `PREFETCHER_TABLE_SIZE; k++)  
                        if (prefetcher_lut[k].LRU_state < prefetcher_lut[matched_index].LRU_state) 
                            prefetcher_lut_next[k].LRU_state++;
                end
                HIT2: begin
                    if (prefetcher_lut[matched_index].stride + prefetcher_lut[matched_index].index == snoop_addr_i[0][INDEX_WIDTH - 1:0]) begin
                        prefetcher_lut_next[matched_index].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                        prefetcher_lut_next[matched_index].training_mode = HIT3;
                    end else begin
                        prefetcher_lut_next[matched_index].stride = snoop_addr_i[0][INDEX_WIDTH - 1:0] - prefetcher_lut[matched_index].index;
                        prefetcher_lut_next[matched_index].index  = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                        prefetcher_lut_next[matched_index].training_mode = INITIAL;
                    end
                    for (int k = 0; k < `PREFETCHER_TABLE_SIZE; k++)  
                        if (prefetcher_lut[k].LRU_state < prefetcher_lut[matched_index].LRU_state) 
                            prefetcher_lut_next[k].LRU_state++;
                end
                HIT3: begin
                    if (prefetcher_lut[matched_index].stride + prefetcher_lut[matched_index].index == snoop_addr_i[0][INDEX_WIDTH - 1:0]) begin
                        prefetcher_lut_next[matched_index].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                        prefetcher_lut_next[matched_index].training_mode = PREFETCHING;
                        if(~sign_stride) begin //Positive Strides
                            sign_stride_input = 1'b0;
                            if((snoop_addr_i[0][INDEX_WIDTH - 1:0] - prefetcher_lut[matched_index].index) < ADDR_WIDTH)
                                prefetcher_lut_next[matched_index].stride = ((((prefetcher_lut[matched_index].stride >> BLOCK_OFFSET_WIDTH) + 1) << BLOCK_OFFSET_WIDTH ) - 1);
                            else
                                prefetcher_lut_next[matched_index].stride = prefetcher_lut[matched_index].stride;
                            end
                        if(sign_stride) begin //Negative Strides
                            sign_stride_input = 1'b1;
                            if((((snoop_addr_i[0][INDEX_WIDTH - 1:0] - prefetcher_lut[matched_index].index) ^  {{(INDEX_WIDTH){1'b1}}}) + 1'b1) < ADDR_WIDTH) //Calculation two's complement
                                prefetcher_lut_next[matched_index].stride = ((((((snoop_addr_i[0][INDEX_WIDTH - 1:0] - 
                                prefetcher_lut[matched_index].index) ^  {{(INDEX_WIDTH){1'b1}}}) + 1'b1) >> BLOCK_OFFSET_WIDTH) + 1) << BLOCK_OFFSET_WIDTH)  - 1;
                            else  
                                prefetcher_lut_next[matched_index].stride = ((snoop_addr_i[0][INDEX_WIDTH - 1:0] - 
                                prefetcher_lut[matched_index].index) ^  {{(INDEX_WIDTH){1'b1}}}) + 1'b1;                                         
                            end
                        end else begin                                                  
                            prefetcher_lut_next[matched_index].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                            prefetcher_lut_next[matched_index].training_mode = INITIAL;
                            prefetcher_lut_next[matched_index].stride = snoop_addr_i[0][INDEX_WIDTH - 1:0] - prefetcher_lut[matched_index].index;
                        end 
                            for (int k = 0; k < `PREFETCHER_TABLE_SIZE; k++)  
                                if (prefetcher_lut[k].LRU_state < prefetcher_lut[matched_index].LRU_state) 
                                    prefetcher_lut_next[k].LRU_state++;                                                                                
                end 
                PREFETCHING: begin
                    hwpf_fifo_write = 1; 
                    hwpf_stride_base_internal[0].base_cline = (snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : 0] + prefetcher_lut[matched_index].stride) 
                                                               & {{(ADDR_WIDTH-BLOCK_OFFSET_WIDTH){1'b1}},{{(BLOCK_OFFSET_WIDTH){1'b0}}}}; 
                    //Calculating Cross Paging
                    if(hpdc_prefetcher_cachelines_r < (num_cacheline_page - 
                        ((((snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : 0] + prefetcher_lut[matched_index].stride) - 
                        (snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : 0] + prefetcher_lut[matched_index].stride)) & PREF_PA_INDEX) 
                         >>  my_log2(prefetcher_lut[matched_index].stride))-1))

                        hwpf_stride_param_internal[0].nblocks = hpdc_prefetcher_cachelines_r;

                    else

                        hwpf_stride_param_internal[0].nblocks = (num_cacheline_page - ((snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : 0] + prefetcher_lut[matched_index].stride) - 
                        ((snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : 0] + prefetcher_lut[matched_index].stride) & 
                        (PREF_PA_INDEX)) >> my_log2(prefetcher_lut[matched_index].stride)))-1;

                    hwpf_stride_base_internal[0].cycle  = '0;
                    hwpf_stride_base_internal[0].rearm  = '0;
                    hwpf_stride_base_internal[0].enable = '1;
                    hwpf_stride_param_internal[0].nlines  = '0; 
                    hwpf_stride_param_internal[0].stride = prefetcher_lut[matched_index].stride;
                    hwpf_stride_throttle_internal[0].ninflight = hpdc_prefetcher_inflight_r; 
                    hwpf_stride_throttle_internal[0].nwait     = hpdc_prefetcher_wait_r;              
                    hwpf_stride_throttle_set_internal = '1;
                    hwpf_stride_param_set_internal    = '1;
                    hwpf_stride_base_set_internal     = '1;    
                    snooping_entry.base = hwpf_stride_base_internal[0]; 
                    snooping_entry.throttle = hwpf_stride_throttle_internal[0];
                    snooping_entry.param = hwpf_stride_param_internal[0];

                    for (int k = 0; k < `PREFETCHER_TABLE_SIZE; k++) 
                        if (prefetcher_lut[k].LRU_state < prefetcher_lut[matched_index].LRU_state) 
                            prefetcher_lut_next[k].LRU_state++;

                    prefetcher_lut_next[matched_index].training_mode = INITIAL;
                    prefetcher_lut_next[matched_index].valid = 1;
                    prefetcher_lut_next[matched_index].LRU_state = '0; 
                    prefetcher_lut_next[matched_index].stride = '0;                                       
                    end 
            endcase
        end 
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        //NO MATCH
        else if (fill_index_valid) begin //Find an Invalid Entry
            prefetcher_lut_next[fill_index].valid = '1;
            prefetcher_lut_next[fill_index].tag = snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : INDEX_WIDTH];           
            prefetcher_lut_next[fill_index].training_mode = INITIAL;
            prefetcher_lut_next[fill_index].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];           
            prefetcher_lut_next[fill_index].stride = '0;   
            prefetcher_lut_next[fill_index].LRU_state = '0; 
            for (int k = 0; k < `PREFETCHER_TABLE_SIZE ; k++)                                   
                if (prefetcher_lut[k].LRU_state < prefetcher_lut[fill_index].LRU_state)    
                    prefetcher_lut_next[k].LRU_state++;
        end else begin 				
            for (int i=0; i < `PREFETCHER_TABLE_SIZE; ++i) begin 
                if(prefetcher_lut[i].LRU_state == '1)   begin  
                    prefetcher_lut_next[i].LRU_state = '0; 
                    prefetcher_lut_next[i].valid = '1;
                    prefetcher_lut_next[i].tag = snoop_addr_i[0][TAG_WIDTH + INDEX_WIDTH - 1 : INDEX_WIDTH];
                    prefetcher_lut_next[i].training_mode = INITIAL;
                    prefetcher_lut_next[i].index = snoop_addr_i[0][INDEX_WIDTH - 1:0];
                    prefetcher_lut_next[i].stride = '0;
                    for (int k = 0; k < `PREFETCHER_TABLE_SIZE ; k++)                                   
                        if (prefetcher_lut[k].LRU_state < prefetcher_lut[replace_index].LRU_state)    
                            prefetcher_lut_next[k].LRU_state++;                                                                            
                end 
            end 
        end 
    end 
end 

//**************************************************************************** FIFO *********************************************************
`ifdef FIFO_Method_1 //if fifo is full do not write new data
  bram_based_fifo #(.Dw (160), .B(`HPDC_PREFETCHER_FIFO)) 
    fifo_1
     (  
        .din ({snooping_entry.base.base_cline, snooping_entry.base.unused, snooping_entry.base.cycle, snooping_entry.base.rearm,
                    snooping_entry.base.enable, snooping_entry.param.nblocks, snooping_entry.param.nlines, snooping_entry.param.stride,
                    snooping_entry.throttle.ninflight, snooping_entry.throttle.nwait}),
        .wr_en (hwpf_fifo_write & ~hwpf_fifo_full), 
        .rd_en (|hwpf_fifo_read),
        .dout  ({hwpf_fifo_out.base.base_cline, hwpf_fifo_out.base.unused, hwpf_fifo_out.base.cycle, hwpf_fifo_out.base.rearm, hwpf_fifo_out.base.enable,
                    hwpf_fifo_out.param.nblocks, hwpf_fifo_out.param.nlines, hwpf_fifo_out.param.stride, hwpf_fifo_out.throttle.ninflight, 
                    hwpf_fifo_out.throttle.nwait}),
        .full  (hwpf_fifo_full),
        .nearly_full (near_full),
        .empty (hwpf_fifo_empty),
        .reset (~rst_ni),
        .clk   (clk_i),
        .rd_ptr     (rdaddr),
        .wr_ptr     (wraddr)
        );    
`else
    fetchflare_bram_based_fifo #(.Dw (160), .B(`HPDC_PREFETCHER_FIFO)) //If the FIFO is nearly full (when only fifo has one free space), throws away the first data from the FIFO.
    fifo_1
        (  
        .din ({snooping_entry.base.base_cline, snooping_entry.base.unused, snooping_entry.base.cycle, snooping_entry.base.rearm,
               snooping_entry.base.enable, snooping_entry.param.nblocks, snooping_entry.param.nlines, snooping_entry.param.stride,
               snooping_entry.throttle.ninflight, snooping_entry.throttle.nwait}),
        .wr_en (hwpf_fifo_write),
        .rd_en (|hwpf_fifo_read | (hwpf_fifo_write & hwpf_fifo_full)),
        .dout  ({hwpf_fifo_out.base.base_cline, hwpf_fifo_out.base.unused, hwpf_fifo_out.base.cycle, hwpf_fifo_out.base.rearm, hwpf_fifo_out.base.enable,
                    hwpf_fifo_out.param.nblocks, hwpf_fifo_out.param.nlines, hwpf_fifo_out.param.stride, hwpf_fifo_out.throttle.ninflight, 
                    hwpf_fifo_out.throttle.nwait}),
        .full  (hwpf_fifo_full),
        .nearly_full (near_full),
        .empty (hwpf_fifo_empty),
        .reset (~rst_ni),
        .clk   (clk_i),
        .rd_ptr     (rdaddr),
        .wr_ptr     (wraddr)
        );  

`endif   

//*************************************************** QUEUE *******************************************************************************/
//This part implements a quque for prefetching requests, it lands between snooping mechanism and prefetching engines.

logic   [NUM_HW_PREFETCH-1:0] hwpf_stride_selected;

fetchflare_arbiter_pref #(
    .ARBITER_WIDTH(NUM_HW_PREFETCH)
) arb (
   .clk(clk_i), 
   .reset(~rst_ni), 
   .request(~hwpf_stride_status_busy), 
   .grant(hwpf_stride_selected),
   .any_grant()
);


logic [NUM_HW_PREFETCH-1:0] hwpf_fifo_read_f;
always @(posedge clk_i) begin
    if(~rst_ni) hwpf_fifo_read_f<='0;
    else hwpf_fifo_read_f<=hwpf_fifo_read;
end

generate
    for (genvar i = 0; i < NUM_HW_PREFETCH; i++) begin
        always_comb   begin
            hwpf_fifo_read[i] =  '0;
            hwpf_stride_base_p[i] =  '0;
            hwpf_stride_param_p[i] = '0;
            hwpf_stride_throttle_p[i] = '0;
            hwpf_stride_base_set_p[i] =  '0; 
            hwpf_stride_param_set_p[i] = '0;
            hwpf_stride_throttle_set_p[i] = '0;
            hwpf_snoop_match[i] = '0;
            if ((~hwpf_fifo_empty) && (hwpf_stride_selected[i])) begin
                 hwpf_fifo_read[i] =  1'b1;
            end
            if(hwpf_fifo_read_f[i]) begin 
                hwpf_stride_base_p[i] =  hwpf_fifo_out.base;
                hwpf_stride_param_p[i] = hwpf_fifo_out.param;
                hwpf_stride_throttle_p[i] = hwpf_fifo_out.throttle;
                hwpf_stride_base_set_p[i] =  '1; 
                hwpf_stride_param_set_p[i] = '1;
                hwpf_stride_throttle_set_p[i] = '1;
                hwpf_snoop_match[i] = 1;
            end  
        end
    end       
endgenerate 


//********************************************************* Hardware prefetcher engines ***********************************************************
    //  {{{
generate
    for (genvar i = 0; i < NUM_HW_PREFETCH; i++) begin: Engine_Run
        assign hwpf_stride_enable[i] = hwpf_stride_base_o[i].enable;  
            fetchflare #(
                .CACHE_LINE_BYTES   ( CACHE_LINE_BYTES ),
                .hpdcache_req_addr_t(hpdcache_req_addr_t),
                .hpdcache_nline_t(hpdcache_nline_t),
                .hpdcache_tag_t(hpdcache_tag_t),
                .hpdcache_req_offset_t(hpdcache_req_offset_t),
                .hpdcache_req_t(hpdcache_req_t),
                .hpdcache_rsp_t(hpdcache_rsp_t)
            ) hwpf_stride_i (
                .clk_i,
                .rst_ni              ( rst_ni & engine_rst_n ),

                .csr_base_set_i      ( hwpf_stride_base_set_p[i] ),
                .sign_stride         ( sign_stride_input),  
                .csr_base_i          ( hwpf_stride_base_p[i] ),             
                .csr_param_set_i     ( hwpf_stride_param_set_p[i] ),       
                .csr_param_i         ( hwpf_stride_param_p[i] ),            
                .csr_throttle_set_i  ( hwpf_stride_throttle_set_p[i] ),    
                .csr_throttle_i      ( hwpf_stride_throttle_p[i] ),      
                .csr_base_o          ( hwpf_stride_base[i] ),         
                .csr_param_o         ( hwpf_stride_param[i] ),            
                .csr_throttle_o      ( hwpf_stride_throttle[i] ),         
                .busy_o              ( hwpf_stride_status_busy[i] ),       

                .snoop_match_i       ( hwpf_snoop_match[i]),                   
    
                .hpdcache_req_valid_o ( hwpf_stride_req_valid[i] ),    
                .hpdcache_req_ready_i ( hwpf_stride_req_ready[i] ),    
                .hpdcache_req_o       ( hwpf_stride_req[i] ),                          
                .hpdcache_rsp_valid_i ( hwpf_stride_arb_in_rsp_valid[i]  ),   
                .hpdcache_rsp_i       ( hwpf_stride_arb_in_rsp[i] ) 
            );

        assign hwpf_stride_req_ready[i]               = hwpf_stride_arb_in_req_ready[i],
               hwpf_stride_arb_in_req_valid[i]        = hwpf_stride_req_valid[i],
               hwpf_stride_arb_in_req[i].addr_offset  = hwpf_stride_req[i].addr_offset,
               hwpf_stride_arb_in_req[i].wdata        = hwpf_stride_req[i].wdata,
               hwpf_stride_arb_in_req[i].op           = hwpf_stride_req[i].op,
               hwpf_stride_arb_in_req[i].be           = hwpf_stride_req[i].be,
               hwpf_stride_arb_in_req[i].size         = hwpf_stride_req[i].size,
               hwpf_stride_arb_in_req[i].sid          = hpdcache_req_sid_i,
               hwpf_stride_arb_in_req[i].tid          = hpdcache_req_tid_t'(i),
               hwpf_stride_arb_in_req[i].need_rsp     = hwpf_stride_req[i].need_rsp,
               hwpf_stride_arb_in_req[i].phys_indexed = hwpf_stride_req[i].phys_indexed,
               hwpf_stride_arb_in_req[i].addr_tag     = hwpf_stride_req[i].addr_tag,
               hwpf_stride_arb_in_req[i].pma          = '0;
            
    end
endgenerate
   
////****************************************************************************************************************************************************************
    //  Hardware prefetcher arbiter between engines
    //  {{{
    fetchflare_arb #(
        .NUM_HW_PREFETCH          ( NUM_HW_PREFETCH ),
        .hpdcache_req_t(hpdcache_req_t),
        .hpdcache_rsp_t(hpdcache_rsp_t)
    ) hwpf_stride_arb_i (
        .clk_i,
        .rst_ni,
        // DCache input interface
        .hwpf_stride_req_valid_i ( hwpf_stride_arb_in_req_valid ),      
        .hwpf_stride_req_ready_o ( hwpf_stride_arb_in_req_ready ),      
        .hwpf_stride_req_i       ( hwpf_stride_arb_in_req ),            
        .hwpf_stride_rsp_valid_o ( hwpf_stride_arb_in_rsp_valid ),      
        .hwpf_stride_rsp_o       ( hwpf_stride_arb_in_rsp ),            
        // DCache output interface
        .hpdcache_req_valid_o,            
        .hpdcache_req_ready_i,           
        .hpdcache_req_o,                  
        .hpdcache_rsp_valid_i,            
        .hpdcache_rsp_i                   
    );           

    //  }}}

endmodule :fetchflare_wrapper
