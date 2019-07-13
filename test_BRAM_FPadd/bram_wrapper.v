module bram_wrapper(clk, rst, data_in, valid_in, numData, data_out, valid_out, ready);

  /* ============================================ */
    input           	clk;
    input           	rst;
    input  [127:0]		data_in;
    input   		  	valid_in;
	input  [19:0]		numData;
    input   		  	ready;

    output reg [127:0]	data_out;
	output reg 			valid_out;
	  
	parameter NUM_OF_PAT = 65536/4;
	parameter MEM_ADDR_WIDTH = $clog2(NUM_OF_PAT);
	
	parameter ADD_PIP_NUM = 8;
	  
	parameter RECI = 2'b00;
	parameter TRAN = 2'b01;
	parameter SEND = 2'b11;
	
	
	wire [31:0] 	alu_data_out;
	wire 			out_en;  
	  
	reg  						UX_r_en;
	reg  [MEM_ADDR_WIDTH-1:0]	UX_in_addr;		//write in
	reg  [MEM_ADDR_WIDTH-1:0]	UX_out_addr;	//read out
	reg  					 	UX_w_en;
	reg  [127:0]  				UX_in;
	wire [127:0]  				UX_out;

    reg  [1:0]	state, state_nxt;
	reg [MEM_ADDR_WIDTH+1:0]	counter,  counter_nxt;
	reg [MEM_ADDR_WIDTH:0]		store_counter, store_counter_nxt;

  /* ============================================ */
    always@(*) begin
		UX_r_en   = 0;
		UX_in_addr  = 0;
		UX_out_addr = 0;
		UX_w_en   = 0;
		UX_in  = 128'd0;
		state_nxt = state;
		counter_nxt = counter;
		store_counter_nxt= store_counter;
		valid_out = 0;
		data_out  = 0;
		case(state)
			RECI: begin
				if(out_en) begin
					counter_nxt = counter+1;
					UX_w_en = 1'b1;	//first (NUM_OF_PAT) data : a
					UX_in_addr = counter[MEM_ADDR_WIDTH-1:0];
					UX_in = {96'd0, alu_data_out};
					if(counter==(numData-1)) begin
						state_nxt   = TRAN;
						counter_nxt = 0;
						//read from block RAM (for tran)
					end
				end
			end
			TRAN: begin
				UX_r_en     = 1;
				UX_out_addr = counter;
				state_nxt = SEND;
			end
			SEND: begin
				valid_out = 1;
				data_out  = UX_out;
				//read from block RAM (for send)
				UX_r_en     = 1;
				UX_out_addr = counter[MEM_ADDR_WIDTH-1:0];
				if(ready) begin
					counter_nxt = counter+1;
					UX_out_addr = counter_nxt[MEM_ADDR_WIDTH-1:0];
				end
			end
        endcase
    end

  /* ============================================ */
    always@(posedge clk or posedge rst)
    begin
        if (rst) begin
			state 	<= RECI;
			counter <= 0;
			store_counter <= 0;
		end
        else begin
			state 	<= state_nxt;
			counter <= counter_nxt;
			store_counter <= store_counter_nxt;
        end
    end
  /* ============================================ */  
  
    alu_add  #(ADD_PIP_NUM) alu_add_u(
		.CLK(clk),
		.RST(rst),
		.in_en(valid_in),
		.data_a(data_in[31:0]),
		.data_b(data_in[63:32]),
		.data_c(data_in[95:64]),
		.data_d(data_in[127:96]),
		.data_out(alu_data_out),
		.out_en(out_en)
	);
  
    data_mem #(128, MEM_ADDR_WIDTH) data_mem_out (
		.CLK(clk), 
		.w_en       (UX_w_en ), 
		.mem_in     (UX_in), 
		.mem_addr_i (UX_in_addr), 
		.r_en       (UX_r_en  ), 
		.mem_out    (UX_out),
		.mem_addr_o (UX_out_addr)
	);

endmodule


//==============================================================================//
module alu_add
#(parameter PIP_NUM = 8)
(CLK, RST, in_en, data_a, data_b, data_c, data_d, data_out, out_en);

	input 		 	CLK;
	input 		 	RST;
	input			in_en;
	input  [31:0] 	data_a;
	input  [31:0] 	data_b;
	input  [31:0] 	data_c;
	input  [31:0] 	data_d;
	output [31:0] 	data_out;
	output 			out_en;
	
	wire [31:0] data_ab, data_cd;
	wire 		out_en_inter;
	
	//pipline stage = 8;FPU_add_sub
	FPU_add_unit  #(PIP_NUM) fp_add_unit1(
		.CLK(CLK),
		.RST(RST),
		.in_en(in_en),
		.data_a(data_a),
		.data_b(data_b),
		.data_out(data_ab),
		.out_en(out_en_inter)
	);
	
	//pipline stage = 8;FPU_add_sub
	FPU_add_unit  #(PIP_NUM) fp_add_unit2(
		.CLK(CLK),
		.RST(RST),
		.in_en(in_en),
		.data_a(data_c),
		.data_b(data_d),
		.data_out(data_cd),
		.out_en()
	);
	
	//pipline stage = 8;FPU_add_sub
	FPU_add_unit  #(PIP_NUM) fp_add_unit3(
		.CLK(CLK),
		.RST(RST),
		.in_en(out_en_inter),
		.data_a(data_ab),
		.data_b(data_cd),
		.data_out(data_out),
		.out_en(out_en)
	);
	
endmodule

//===========================================================================//

//==============================================================================//
module FPU_add_unit
#(parameter PIP_NUM = 8)
(CLK, RST, in_en, data_a, data_b, data_out, out_en);

	input 		 	CLK;
	input 		 	RST;
	input			in_en;
	input  [31:0] 	data_a;
	input  [31:0] 	data_b;
	output [31:0] 	data_out;
	output 			out_en;

	reg buf_reg      [PIP_NUM-1:0];
	reg buf_reg_nxt  [PIP_NUM-1:0];

	integer i;

	assign out_en = buf_reg[PIP_NUM-1];

	always@(posedge CLK or posedge RST)begin
		if(RST)begin
			for(i=0;i<PIP_NUM;i=i+1)begin
				buf_reg[i] <= 0;
			end
		end
		else begin
			for(i=0;i<PIP_NUM;i=i+1)begin
				buf_reg[i] <= buf_reg_nxt[i];
			end
		end
	end

	always@(*)begin
		buf_reg_nxt[0] = in_en;
		for(i=0;i<PIP_NUM-1;i=i+1)begin
			buf_reg_nxt[i+1] = buf_reg[i];
		end
	end

	//pipline stage = 8;FPU_add_sub
	FPU_add_sub  fp_add_unit(
	.clock(CLK),
	.dataa(data_a),
	.datab(data_b),
	.result(data_out)
	);
	
endmodule

//===========================================================================//
//==============================================================================//

// Quartus II Verilog Template
// True Dual Port RAM with single clock
module data_mem
#(parameter DATA_WIDTH=128, parameter ADDR_WIDTH=7)
(
	input [(DATA_WIDTH-1):0] mem_in,
	// input [(DATA_WIDTH-1):0] data_b,
	input [(ADDR_WIDTH-1):0] mem_addr_i, mem_addr_o,
	input w_en, r_en, CLK,
	// output reg [(DATA_WIDTH-1):0] q_a,
	output reg [(DATA_WIDTH-1):0] mem_out
);

	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

	// Port A 
	always @ (posedge CLK)
	begin
		if (w_en) begin
			ram[mem_addr_i] <= mem_in;
		end 
	end 

	// Port B 
	always @ (posedge CLK)
	begin
		if (r_en) begin
			mem_out <= ram[mem_addr_o];
		end 
	end

endmodule
