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
 
