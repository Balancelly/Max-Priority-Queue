module MPQ(clk,rst,data_valid,data,cmd_valid,cmd,index,value,busy,RAM_valid,RAM_A,RAM_D,done);
input clk;
input rst;
input data_valid;
input [7:0] data;
input cmd_valid;
input [2:0] cmd;
input [7:0] index;
input [7:0] value;
output reg busy;
output reg RAM_valid;
output reg[7:0]RAM_A;
output reg [7:0]RAM_D;
output reg done;

reg [7:0] a [15:0];//max=13
reg [2:0] cs,ns;
reg [3:0] read_counter;
reg [2:0] up_counter;
reg [2:0] down_counter;
reg [3:0] write_counter,max_heap;
parameter read=3'd0,hold=3'd1,up_build=3'd2,down_build=3'd3,ex_max=3'd4,inc_val=3'd5,ins_val=3'd6,write=3'd7,finish=3'd8;//cs=4&&6 change the size
//cs
always@(posedge clk or posedge rst)begin
	if(rst)begin	
		cs <= read;
	end
	else begin
		cs <= ns;
	end
end

//fsm
always@(*)begin
	case(cs)
		read:
		begin
			if(read_counter==4'd11)begin//0 1...11 max_heap=12
				ns = hold;
			end
			else begin
				ns = read;
			end
		end
		hold://receive cmd
		begin
			if(cmd == 3'd0)begin
				ns = up_build;
			end
			else if(cmd == 3'd1)begin
				ns = ex_max;
			end
			else if(cmd == 3'd2)begin
				ns = inc_val;
			end
			else if(cmd == 3'd3)begin
				ns = ins_val;
			end
			else if(cmd == 3'd4)begin
				ns = write;
			end
			else begin
				ns = hold;
			end
		end
		up_build://down to up
		begin
			if(up_counter==3'd0)begin
				ns = down_build;
			end
			else begin
				ns = up_build;
			end
		end
		down_build://up to down
		begin
			if(((down_counter<<1)+4'd1)>=(max_heap-4'd1))begin
				ns = hold;
			end
			else begin
				ns = down_build;
			end
		end
		ex_max:ns=up_build;	//1clk
		inc_val:ns=up_build;		//1clk
		ins_val:ns=up_build;		//1clk
		write://at the last
		begin
			if(write_counter== max_heap+4'd1)begin
				ns = finish;
			end
			else begin
				ns = write;
			end
		end
		finish:ns = read;
		default:ns = read;
	endcase
end
//====================================================================================
//busy
always@(*)begin
	if(cs==hold) busy = 1'd0;
	else busy = 1'd1;
end

//done
always@(posedge clk or posedge rst)begin
	if(rst)begin
		done<=1'd0;
	end
	else begin
		if(cs==write && write_counter== max_heap+4'd1) done <= 1'd1;
		else done <= 1'd0;
	end
end

//RAM_valid
always@(*)begin
	if(cs==write) RAM_valid=1'd1;
	else RAM_valid=1'd0;
end
//================================================
//counter
//read_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		read_counter<=4'd0;
	end
	else begin
		if(cs==read && read_counter<4'd11)begin//read counter from 0 to 11
			read_counter<=read_counter+4'd1;
		end
		else begin
			read_counter<=4'd0;
		end
	end
end
		
//up_counter //down to up
always@(posedge clk or posedge rst)begin
	if(rst)begin
		up_counter<=3'd0;
	end
	else if(cs==hold && cmd ==3'd0)begin//ns=build
		up_counter<=(max_heap-4'd1)>>1; //up counter from 5 to 0
	end
	else if(cs==ex_max)begin//-1
		up_counter<=(max_heap-4'd2)>>1;
	end
	else if(cs==inc_val)begin//0
		up_counter<=(max_heap-4'd1)>>1;
	end
	else if(cs==ins_val)begin//+1
		up_counter<=(max_heap)>>1;
	end		
	else if(cs==up_build && ((up_counter<<1)+4'd1)<= max_heap && up_counter>3'd0)begin//2*up+1<=11 up<=5 /5 4 3 2 1 0
		up_counter<=up_counter-3'd1;
	end
	else begin
		up_counter<=3'd0;
	end
end

//down_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		down_counter<=3'd0;
	end
	else if(cs==down_build && down_counter>=3'd0 && ((down_counter<<1)+4'd1)< (max_heap-4'd1))begin//max_heap=11 2*down+1<10 down4.5  /0 1 2 3 4 (5) // max_heap=10 2*down+1<9 down<4  /0 1 2 3 (4)
		down_counter<=down_counter+3'd1;
	end
	else begin
		down_counter<=3'd0;
	end
end

//write_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		write_counter<=4'd0;
	end
	else if(cs==hold && cmd==3'd4)begin
		write_counter<=write_counter+4'd1;
	end
	else if(cs==write && write_counter>=4'd0 && write_counter<max_heap+4'd1)begin//max_heap=12 +1=13 0 1 ..12 13
		write_counter<=write_counter+4'd1;
	end
	else if(cs==write && write_counter>=4'd0 && write_counter== max_heap+4'd1)begin//12
		write_counter<=4'd0;
	end
	else begin
		write_counter<=write_counter;
	end
end

//max_heap
always@(posedge clk or posedge rst)begin
	if(rst)begin
		max_heap<=4'd0;
	end
	else begin
		if(cs==read)begin
			max_heap<=4'd11;
		end
		else if(cs==ex_max)begin//pop 1 minus 1
			max_heap<=max_heap-4'd1;
		end
		else if(cs==ins_val)begin //insert 1 add 1
			max_heap<=max_heap+4'd1;
		end
		else begin
			max_heap<=max_heap;
		end
	end
end
//===================================================
//r l 
/*always@(*)begin
	if(cs==up_build)begin
		l=(up_counter<<1)+4'd1;//l=2*up+1  
		r=(up_counter<<1)+4'd2;//r=2*up+2 0 1 2
		l_m=4'd0;
		r_m=4'd0;
	end
	else if(cs==down_build)begin
		l=4'd0;
		r=4'd0;
		l_m=(down_counter<<1)+4'd1;
		r_m=(down_counter<<1)+4'd2;
	end
	else begin
		l=4'd0;
		r=4'd0;
		l_m=4'd0;
		r_m=4'd0;
	end
end
*/
//read_data //build
always@(posedge clk or posedge rst)begin
	if(rst)begin
		a[0]<=8'd0;
		a[1]<=8'd0;
		a[2]<=8'd0;
		a[3]<=8'd0;
		a[4]<=8'd0;
		a[5]<=8'd0;
		a[6]<=8'd0;
		a[7]<=8'd0;
		a[8]<=8'd0;
		a[9]<=8'd0;
		a[10]<=8'd0;
		a[11]<=8'd0;
		a[12]<=8'd0;
		a[13]<=8'd0;
		a[14]<=8'd0;
		a[15]<=8'd0;
	end
	else begin
		if(cs==read && read_counter>=4'd0 && read_counter<4'd12)begin//0 1 2..11
			a[read_counter] <= data;
		end
		else if(cs==up_build)begin//max_heap==11 fixed
			if(((up_counter<<1)+4'd1)<= max_heap && a[(up_counter<<1)+4'd1]>a[up_counter] && a[(up_counter<<1)+4'd1]>=a[(up_counter<<1)+4'd2])begin//l big  l<
				a[up_counter]<=a[(up_counter<<1)+4'd1];
				a[(up_counter<<1)+4'd1]<=a[up_counter];
			end
			else if(((up_counter<<1)+4'd2)<= max_heap && a[(up_counter<<1)+4'd2]>a[up_counter] && a[(up_counter<<1)+4'd2]>a[(up_counter<<1)+4'd1])begin//r_big
				a[up_counter]<=a[(up_counter<<1)+4'd2];
				a[(up_counter<<1)+4'd2]<=a[up_counter];
			end
			else begin
				a[up_counter]<=a[up_counter];
			end
		end
		else if(cs==ex_max)begin
			a[0]<=a[max_heap];//pop max  max_heap-1
			a[max_heap]<=8'd0;
		end
		else if(cs==down_build)begin //max_heap=10 variable
			if(((down_counter<<1)+4'd1) <= max_heap && a[(down_counter<<1)+4'd1]>a[down_counter] && a[(down_counter<<1)+4'd1]>=a[(down_counter<<1)+4'd2])begin//l big  l<
				a[down_counter]<=a[(down_counter<<1)+4'd1];
				a[(down_counter<<1)+4'd1]<=a[down_counter];
			end
			else if(((down_counter<<1)+4'd2)<= max_heap && a[(down_counter<<1)+4'd2]>a[down_counter] && a[(down_counter<<1)+4'd2]>a[(down_counter<<1)+4'd1])begin//r_big
				a[down_counter]<=a[(down_counter<<1)+4'd2];
				a[(down_counter<<1)+4'd2]<=a[down_counter];
			end
			else begin
				a[down_counter]<=a[down_counter];
			end
		end	
		else if(cs==hold && cmd==3'd2)begin//cs==inc_val 3'd5 
			if(value>a[index])begin	
				a[index]<=value;
			end
			else begin
				a[index]<=a[index];
			end
		end
		else if(cs==hold && cmd==3'd3)begin//until build ,max_heap+1 
			a[max_heap+1]<=value;
		end
		else if(cs==finish)begin
			a[0]<=8'd0;
			a[1]<=8'd0;
			a[2]<=8'd0;
			a[3]<=8'd0;
			a[4]<=8'd0;
			a[5]<=8'd0;
			a[6]<=8'd0;
			a[7]<=8'd0;
			a[8]<=8'd0;
			a[9]<=8'd0;
			a[10]<=8'd0;
			a[11]<=8'd0;
			a[12]<=8'd0;
			a[13]<=8'd0;
			a[14]<=8'd0;
			a[15]<=8'd0;
		end
		else begin
			a[read_counter] <= a[read_counter];
		end
	end
end
			
//write_data
always@(posedge clk or posedge rst)begin
	if(rst)begin
		RAM_D<=8'd0;
	end
	else begin
		if(cs==write && write_counter<max_heap+4'd1)begin//if max_heap=11 12value 0 1 2//11
			RAM_D<=a[write_counter];
		end
		else if(cs==hold &&cmd==3'd4)begin
			RAM_D<=a[write_counter];
		end
		else begin
			RAM_D<=RAM_D;
		end
	end
end

//write_addr
always@(posedge clk or posedge rst)begin
	if(rst)begin
		RAM_A<=8'd0;
	end
	else begin
		if(cs==write && write_counter<max_heap+4'd1)begin//0 1 2 3 ...11 12
			RAM_A<=RAM_A+8'd1;
		end
		else if(cs==finish)begin
			RAM_A<=8'd0;
		end
		else begin
			RAM_A<=RAM_A;
		end
	end
end

endmodule
