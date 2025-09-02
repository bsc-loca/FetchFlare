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
/*****************************************************
*
*    thermo_arbiter RRA
*
******************************************************/

module thermo_gen_pref #(
    parameter WIDTH=16


)(
    input  [WIDTH-1    :    0]in,
    output [WIDTH-1    :    0]out
);
    genvar i;
    generate
    for(i=0;i<WIDTH;i=i+1)begin :lp
        assign out[i]= | in[i    :0];    
    end
    endgenerate

endmodule
 
