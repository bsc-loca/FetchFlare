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
 *  Authors       : Alireza Monemi
 *  Creation Date : September, 2023
 *  Description   : Linear Hardware Memory Prefetcher wrapper.
 *  History       :
 */
/****************FIFO******************/

        /* bram_based_fifo */

/*************************************/


module bram_based_fifo  #(
        parameter Dw = 160,//data_width
        parameter B  = 16// buffer num
        )(
        din,   
        wr_en, 
        rd_en, 
        dout,  
        full,
        nearly_full,
        empty,
        reset,
        clk,
        rd_ptr,
        wr_ptr
        );

 
    function integer log2;
        input integer number; begin   
            log2=(number <=1) ? 1: 0;    
            while(2**log2<number) begin    
                log2=log2+1;    
            end        
        end   
    endfunction // log2 

    localparam  B_1 = B-1,
        Bw = log2(B),
        DEPTHw=log2(B+1);
    localparam  [Bw-1   :   0] Bint =   B_1[Bw-1    :   0];

    input [Dw-1:0] din;     // Data in
    input          wr_en;   // Write enable
    input          rd_en;   // Read the next word

    output reg [Dw-1:0]  dout;    // Data out
    output         full;
    output         nearly_full;
    output         empty;

    input          reset;
    input          clk;

            
           reg [Dw-1       :   0] queue [B-1 : 0] /* synthesis ramstyle = "no_rw_check" */;
    output reg [Bw- 1      :   0] rd_ptr;
    output reg [Bw- 1      :   0] wr_ptr;
           reg [DEPTHw-1   :   0] depth;

    // Sample the data
    always @(posedge clk)
    begin
        if (wr_en)
            queue[wr_ptr] <= din;
        if (rd_en)
            dout <=   queue[rd_ptr];
    end

    always @(posedge clk)
    begin
        if (reset) begin
            rd_ptr <= {Bw{1'b0}};
            wr_ptr <= {Bw{1'b0}};
            depth  <= {DEPTHw{1'b0}};
        end
        else begin
            if (wr_en)
            wr_ptr <= (wr_ptr==Bint)? {Bw{1'b0}} : wr_ptr + 1'b1;
            if (rd_en) rd_ptr <= (rd_ptr==Bint)? {Bw{1'b0}} : rd_ptr + 1'b1;
            if (wr_en & ~rd_en) depth <=  depth + 1'b1;
            else if (~wr_en & rd_en) depth <=  depth - 1'b1;
        end
    end

    //assign dout = queue[rd_ptr];
    localparam  [DEPTHw-1   :   0] Bint2 =   B_1[DEPTHw-1   :   0];


    assign full = depth == B [DEPTHw-1   :   0];
    assign nearly_full = depth >=Bint2; //  B-1
    assign empty = depth == {DEPTHw{1'b0}};

    //synthesis translate_off
    //synopsys  translate_off
    always @(posedge clk)
    begin
        if(~reset)begin
            if (wr_en && depth == B[DEPTHw-1   :   0] && !rd_en) begin
                $display(" %t: ERROR: Attempt to write to full FIFO: %m",$time);
                $finish;
            end   
            if (rd_en && depth == {DEPTHw{1'b0}}) begin
                $display("%t: ERROR: Attempt to read an empty FIFO: %m",$time);
                $finish;
            end
        end//~reset
    end
    //synopsys  translate_on
    //synthesis translate_on

endmodule // fifo
