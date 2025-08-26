module arbiter_pref #(
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




    thermo_gen_pref #(
        .WIDTH(ARBITER_WIDTH)
    ) tm1
    (
        .in(request),
        .out(termo1)
    );




    thermo_gen_pref #(
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
