`timescale 1ns/1ns
module chnl_tester #(
	parameter C_PCI_DATA_WIDTH = 9'd32
)
(
	input CLK,
	input RST,
	output CHNL_RX_CLK, 
	input CHNL_RX, 
	output CHNL_RX_ACK, 
	input CHNL_RX_LAST, 
	input [31:0] CHNL_RX_LEN, 	//Used for system size*num of rows(*4)
	input [30:0] CHNL_RX_OFF, 	//Used for nothing
	input [C_PCI_DATA_WIDTH-1:0] CHNL_RX_DATA, 
	input CHNL_RX_DATA_VALID, 
	output CHNL_RX_DATA_REN,
	
	output CHNL_TX_CLK, 
	output CHNL_TX, 
	input CHNL_TX_ACK, 
	output CHNL_TX_LAST, 
	output [31:0] CHNL_TX_LEN, 
	output [30:0] CHNL_TX_OFF, 
	output [C_PCI_DATA_WIDTH-1:0] CHNL_TX_DATA, 
	output CHNL_TX_DATA_VALID, 
	input CHNL_TX_DATA_REN
);

//parameter NUM_SYS = 512;
//parameter NUM_ROWS= 512;
//parameter MEM_ADDR_WIDTH = 7+SYSTEM_PROC_ONE_TIME;

parameter IDLE 			= 3'd0;
parameter RECI 			= 3'd2;
parameter TX_PREP		= 3'd3;
parameter SEND			= 3'd4;

//wire[31:0] SYSTEM_SIZE;

reg [31:0] rLen, rLen_nxt;
reg [30:0] rOff, rOff_nxt;
reg [31:0] rCount, rCount_nxt;
reg [2:0]  rState, rState_nxt;

//Thomas Core input
wire  [C_PCI_DATA_WIDTH-1:0]  		data_in;
wire  		 						valid_in;
wire [C_PCI_DATA_WIDTH-1:0]      	data_out;
wire       	 						valid_out;
wire		 						ready;

reg								in_en, in_en_nxt;
reg [C_PCI_DATA_WIDTH-1:0]		reci_data,reci_data_nxt;


//assign SYSTEM_SIZE = (rLen>>2);

assign data_in 	= reci_data;
assign valid_in = in_en;
assign ready   	= CHNL_TX_DATA_REN;

////////////////////////////////////////////////////////////////

assign CHNL_RX_CLK = CLK;
assign CHNL_RX_ACK = (rState == RECI);
assign CHNL_RX_DATA_REN = (rState == RECI);

assign CHNL_TX_CLK = CLK;
assign CHNL_TX = (rState == SEND);
assign CHNL_TX_LAST = 1'd1;
assign CHNL_TX_LEN = rLen; // in words (System size*num of rows/4(*4))
assign CHNL_TX_OFF = 0;
assign CHNL_TX_DATA = data_out;
assign CHNL_TX_DATA_VALID = valid_out;

always @(*) begin
	rLen_nxt   	= rLen;
	rState_nxt  = rState;
	rCount_nxt  = rCount;
	rOff_nxt 	= rOff;
	in_en_nxt   = 0;
	reci_data_nxt = 0;
	case (rState)		
		IDLE: begin // Wait for start of RX, save length
			if (CHNL_RX) begin
				rLen_nxt =  CHNL_RX_LEN; //system size*num of rows(*4)
				rOff_nxt =  CHNL_RX_OFF;
				rCount_nxt =  0;
				rState_nxt =  RECI;
			end
		end
		
		RECI: begin // Wait for last data in RX, save value
			if (CHNL_RX_DATA_VALID) begin
				reci_data_nxt = CHNL_RX_DATA;
				in_en_nxt   = 1;
				rCount_nxt  =  rCount + (C_PCI_DATA_WIDTH/32);
			end
			if (rCount >= rLen) begin
				rState_nxt = TX_PREP;
			end
		end
		TX_PREP: begin // Prepare for TX
			rCount_nxt =  (C_PCI_DATA_WIDTH/32);
			if(valid_out) begin
				rState_nxt =  SEND;
			end
		end

		SEND: begin // Start TX with save length and data value
			if (CHNL_TX_DATA_REN) begin
				rCount_nxt =  rCount + (C_PCI_DATA_WIDTH/32);
				if (rCount >= rLen) begin
					rState_nxt =  IDLE;
				end
			end
		end	
	endcase
end

always @(posedge CLK or posedge RST) begin
	if (RST) begin
		rLen <=  0;
		rOff <=	 0;
		rCount <=  0;
		rState <=  0;
		reci_data	<= 0;
		in_en	<= 0;
	end
	else begin
		rLen 	<=  rLen_nxt;
		rOff	<=  rOff_nxt;
		rCount 	<=  rCount_nxt;
		rState 	<=  rState_nxt;
		reci_data	<= reci_data_nxt;
		in_en	<= in_en_nxt;
	end
end

bram_wrapper dut(
	.clk(CLK), 
	.rst(RST), 
	.data_in(data_in), 
	.valid_in(valid_in),
	.numData(rLen[21:2]),
	.data_out(data_out), 
	.valid_out(valid_out), 
	.ready(ready)
);

/*
thomas_wrapper #(NUM_SYS, NUM_ROWS)  Thomas_core_unit
(
	.CLK(CLK),
	.RST(RST),
	.XXXX_in(LDUX_in),
	.valid_in(valid_in),
	.num_iter(rOff[19:0]),	//20 bits is more than enough
	.XXXX_out(XXXX_out),	//true if input wants another LDU
	.valid_out(valid_out),
	.ready(ready)	
);
*/

endmodule
//
