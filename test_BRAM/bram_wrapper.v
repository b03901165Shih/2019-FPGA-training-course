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
	  
	parameter RECI = 2'b00;
	parameter TRAN = 2'b01;
	parameter SEND = 2'b11;
	  
	  
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
				if(valid_in) begin
					counter_nxt = counter+1;
					UX_w_en = 1'b1;	//first (NUM_OF_PAT) data : a
					UX_in_addr = counter[MEM_ADDR_WIDTH-1:0];
					UX_in = data_in;
					if(counter==(numData-1)) begin
						state_nxt   = TRAN;
						counter_nxt = numData-1;
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
				data_out  = {UX_out[31:0], UX_out[63:32], UX_out[95:64], UX_out[127:96]};
				//read from block RAM (for send)
				UX_r_en     = 1;
				UX_out_addr = counter[MEM_ADDR_WIDTH-1:0];
				if(ready) begin
					counter_nxt = counter-1;
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
  
    data_mem #(128, MEM_ADDR_WIDTH) data_a_mem (
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
