module LCD_CTRL(clk, reset, IROM_Q, cmd, cmd_valid, IROM_EN, IROM_A, IRB_RW, IRB_D, IRB_A, busy, done);
input clk;
input reset;
input [7:0] IROM_Q;
input [2:0] cmd;
input cmd_valid;
output IROM_EN;
output [5:0] IROM_A;
output IRB_RW;
output [7:0] IRB_D;
output [5:0] IRB_A;
output busy;
output done;

reg [7:0] IRB_D;
reg [2:0] pos_Y,pos_X;
reg [7:0] Image [0:63]; 

//state machine
reg [3:0] cs,ns,cs_reg;
parameter 	IDLE = 4'd0,
			SHIFT_UP = 4'd1,
			SHIFT_DOWN = 4'd2,
			SHIFT_LEFT = 4'd3,
			SHIFT_RIGHT = 4'd4,
			AVERAGE = 4'd5,
			MIRROR_X = 4'd6,
			MIRROR_Y = 4'd7,
			WRITE = 4'd8,
			DONE = 4'd9,
			READ = 4'd10,
			RST = 4'd11;
//state switch
always@(posedge clk or posedge reset)
begin
	if(reset) cs <= RST;
	else cs <= ns;
end

//next state logic
always@(*)
begin
	case(cs)
	RST: ns = READ;
	READ:
	begin
		if(IROM_A == 6'd63) ns = IDLE;
		else ns = READ;
	end
	IDLE:
	begin
		if(cmd_valid)
		begin
			case(cmd)
			3'd0: ns = WRITE;
			3'd1: ns = SHIFT_UP;
			3'd2: ns = SHIFT_DOWN;
			3'd3: ns = SHIFT_LEFT;
			3'd4: ns = SHIFT_RIGHT;
			3'd5: ns = AVERAGE;
			3'd6: ns = MIRROR_X;
			3'd7: ns = MIRROR_Y;
			endcase
		end
		else ns = IDLE;
	end
	SHIFT_UP: ns = IDLE;
	SHIFT_DOWN: ns = IDLE;
	SHIFT_RIGHT: ns = IDLE;
	SHIFT_LEFT: ns = IDLE;
	MIRROR_X: ns = IDLE;
	MIRROR_Y: ns = IDLE;
	AVERAGE: ns = IDLE;
	WRITE: 
	begin
		if(IRB_A == 6'd63) ns = DONE;
	   	else ns = WRITE;	
	end
	DONE: ns = DONE;
	default: ns = IDLE;
	endcase
end

//pos_X , pos_Y
always@(posedge clk or posedge reset)
begin
	if(reset) {pos_Y,pos_X} <= 6'd0;
	else
	begin
		if( (cs == READ && ns == READ) || cs == WRITE) {pos_Y,pos_X} <= {pos_Y,pos_X} + 6'd1;
		else if(cs == IDLE && cmd_valid == 1'd1 && cmd == 3'd0) {pos_Y,pos_X} <= 6'd0;
		else if(cs == READ && IROM_A == 6'd63) {pos_Y,pos_X} <= {3'd4,3'd4};
		else 
		begin
			case(cs)
			SHIFT_UP: {pos_Y,pos_X} <= (pos_Y==3'd1) ? {pos_Y,pos_X} : ({pos_Y,pos_X} - 6'd8);
			SHIFT_DOWN: {pos_Y,pos_X} <= (pos_Y==3'd7) ? {pos_Y,pos_X} : ({pos_Y,pos_X} + 6'd8);
			SHIFT_LEFT: {pos_Y,pos_X} <= (pos_X==3'd1) ? {pos_Y,pos_X} : ({pos_Y,pos_X} - 6'd1);
			SHIFT_RIGHT: {pos_Y,pos_X} <= (pos_X==3'd7) ? {pos_Y,pos_X} : ({pos_Y,pos_X} + 6'd1);
			endcase
		end
	end
end

//output

//IROM_EN
//wire IROM_EN = (cs == READ || cs_reg == READ) ? 1'd0 : 1'd1;
reg IROM_EN;
always@(posedge clk or posedge reset)
begin
	if(reset) IROM_EN <= 1'd0;
	else if(cs == READ || ns == READ) IROM_EN <= 1'd0;
	else IROM_EN <= 1'd1;
end

//busy
//wire busy = (cs == DONE || cs == IDLE) ? 1'd0 : 1'd1;
reg busy;
always@(posedge clk or posedge reset)
begin
	if(reset) busy <= 1'd1;
	else if(ns == IDLE || ns == DONE) busy <= 1'd0;
	else busy <= 1'd1;
end

//IRB_RW
//wire IRB_RW = (cs == WRITE || cs == DONE) ? 1'd0 : 1'd1;

reg IRB_RW;
always@(posedge clk or posedge reset)
begin
	if(reset) IRB_RW <= 1'd1;
	else if(cmd_valid == 1'd1 && cmd == 3'd0) IRB_RW <= 1'd0;
end

//done
wire done = (cs == DONE) ? 1'd1 : 1'd0;
/*
reg done;
always@(posedge clk or posedge reset)
begin
	if(reset) done <= 1'd0;
	else if(cs == DONE) done <= 1'd1;
end
*/
//IROM_A
wire [5:0] IROM_A = {pos_Y,pos_X};

//IRB_A
wire [5:0] IRB_A = {pos_Y,pos_X};

//cs_reg delay cs 1 clk
always@(posedge clk)
begin
	cs_reg <= cs;
end

//index x y
wire [5:0] index_0 = {pos_Y-3'd1,pos_X-3'd1};
wire [5:0] index_1 = {pos_Y-3'd1,pos_X};
wire [5:0] index_2 = {pos_Y,pos_X-3'd1};
wire [5:0] index_3 = {pos_Y,pos_X};

//sum
wire [9:0] sum = (Image[index_0] + Image[index_1]) + (Image[index_2] + Image[index_3]);

//Image
integer i;
always@(posedge clk or posedge reset)
begin
	if(reset)
	begin
		for(i=0;i<64;i=i+1)
		begin
			Image[i] <= 8'd0;
		end
	end
	else if(cs == READ) Image[IROM_A-6'd1] <= IROM_Q;
	else if(cs_reg == READ) Image[6'h3f] <= IROM_Q;
	else if(cs == MIRROR_X) 
	begin
		Image[index_0] <= Image[index_2];
		Image[index_1] <= Image[index_3];
		Image[index_2] <= Image[index_0];
		Image[index_3] <= Image[index_1];	
	end
	else if(cs == MIRROR_Y)
	begin
		Image[index_0] <= Image[index_1];
		Image[index_1] <= Image[index_0];
		Image[index_2] <= Image[index_3];
		Image[index_3] <= Image[index_2];	
	end
	else if(cs == AVERAGE)
	begin
		Image[index_0] <= sum[9:2];
		Image[index_1] <= sum[9:2];
		Image[index_2] <= sum[9:2];
		Image[index_3] <= sum[9:2];
	end
end

//IRB_D
always@(posedge clk or posedge reset)
begin
	if(reset) IRB_D <= 8'd0;
	else if(cs == IDLE && ns == WRITE) IRB_D <= Image[6'd0];
	else if(cs == WRITE) IRB_D <= Image[IRB_A+6'd1];
end

endmodule

