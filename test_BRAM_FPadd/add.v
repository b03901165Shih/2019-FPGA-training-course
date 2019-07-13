
//231 machine: 	/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_addsub.v
//2174 machine: /cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_addsub.v

`include "/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_addsub.v"
//`include "/usr/cad/synopsys/synthesis/cur/dw/sim_ver/DW_fp_addsub.v"

module FPU_add_sub(
    clock,
    dataa,
    datab,
    result
);

    parameter pip_num = 8;      

    input           clock;
    input  [31:0]   dataa;
    input  [31:0]   datab;
    output [31:0]   result;
    wire   [31:0]   z;

    reg [31:0] buf_reg      [pip_num-2:0];
    reg [31:0] buf_reg_w    [pip_num-2:0] ;

	reg [31:0] dataa_pip;
	reg [31:0] datab_pip;
    integer i;

    assign result = buf_reg[pip_num-2];

    always@(posedge clock)begin
		dataa_pip <= dataa;
		datab_pip <= datab;
        for(i=0;i<pip_num-1;i=i+1)begin
            buf_reg[i] <= buf_reg_w[i];
        end
    end

    always@(*)begin
        buf_reg_w[0] = z;
        
        for(i=0;i<pip_num-2;i=i+1)begin
            buf_reg_w[i+1] = buf_reg[i];
        end

    end

	// 0 for add, 1 for sub
    DW_fp_addsub sub_module(
        .a(dataa_pip),
        .b(datab_pip),
        .rnd(3'b000),
		.op(1'b0),
        .z(z),
        .status()
    );



endmodule
