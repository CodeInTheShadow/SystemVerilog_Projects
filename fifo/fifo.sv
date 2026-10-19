module fifo(
  input bit clk, rst, rd, wr, 
  input [7:0] din, 
  output logic full, empty, 
  output logic [7:0] dout
);
  logic [7:0] mem [15:0];
  logic [3:0] rdptr=4'b0000, wrptr=4'b0000;
  logic [4:0] count=5'b00000;
  
  assign full = (count == 5'b10000);
  assign empty = (count == 5'b00000);
  
  always @(posedge clk) begin
    if (rst) begin
      rdptr<=4'b0000;
      wrptr<=4'b0000;
      count<=5'b00000;
      dout<=8'b00000000;
    end
    else if (rd && wr && full) begin
      $display("Data %0d popped", mem[rdptr]);
      dout<=mem[rdptr];
      rdptr<=rdptr+1;
      mem[wrptr]<=din;
      $display("Data %0d added", din);
      wrptr<=wrptr+1;
    end
    else if (rd && wr && empty) begin
      mem[wrptr]<=din;
      $display("Data %0d added", din);
      wrptr<=wrptr+1;
      count<=count+1;
    end
    else if (rd && wr && !full && !empty) begin
      $display("Data %0d popped", mem[rdptr]);
      dout<=mem[rdptr];
      rdptr<=rdptr+1;
      mem[wrptr]<=din;
      $display("Data %0d added", din);
      wrptr<=wrptr+1;
    end
    else if (wr && full) begin
      $display("FIFO is full.");
    end
    else if (wr && !full) begin
      mem[wrptr]<=din;
      $display("Data %0d added", din);
      wrptr<=wrptr+1;
      count<=count+1;
    end
    else if (rd && empty) begin
      $display("FIFO is empty.");      
    end
    else if (rd && !empty) begin
      $display("Data %0d popped", mem[rdptr]);
      dout<=mem[rdptr];
      rdptr<=rdptr+1;
      count<=count-1;
    end
  end
endmodule

interface fifo_if;
  
  bit clk, rst, rd, wr;
  logic [7:0] din;
  logic full, empty;
  logic [7:0] dout;
  
  clocking drv_cb @(negedge clk);
    output rst, rd, wr, din;
  endclocking
  
  clocking mon_cb @(posedge clk);
    input #0 rst, rd, wr, din, empty, full, dout;
  endclocking
  
endinterface
