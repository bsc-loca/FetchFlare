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
module fetchflare_arbiter_pref #(
parameter    ARBITER_WIDTH    = 4        
)
(    
   clk, 
   reset, 
   request, 
   grant,
   any_grant
);

        

    
    input     [ARBITER_WIDTH-1            :    0]    request;
    output    [ARBITER_WIDTH-1            :    0]    grant;
    output                                           any_grant;
    input                                            reset,clk;
    
    
    wire        [ARBITER_WIDTH-1             :    0]    termo1,termo2,mux_out,masked_request,edge_mask;
    reg         [ARBITER_WIDTH-1             :    0]    pr;




    fetchflare_thermo_gen_pref #(
        .WIDTH(ARBITER_WIDTH)
    ) tm1
    (
        .in(request),
        .out(termo1)
    );




    fetchflare_thermo_gen_pref #(
        .WIDTH(ARBITER_WIDTH)
    ) tm2
    (
        .in(masked_request),
        .out(termo2)
    );

    
    assign mux_out=(termo2[ARBITER_WIDTH-1])? termo2 : termo1;
    assign masked_request= request & pr;
    assign any_grant=termo1[ARBITER_WIDTH-1];
    
    always @ (posedge clk )begin 
            if(reset) pr<= {ARBITER_WIDTH{1'b1}};
        else begin 
            if(any_grant) pr<= edge_mask;
        end
    
    end
    
    assign edge_mask= {mux_out[ARBITER_WIDTH-2:0],1'b0};
    assign grant= mux_out ^ edge_mask;



endmodule
