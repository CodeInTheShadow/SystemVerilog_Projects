`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/14/2026 07:46:32 PM
// Design Name: 
// Module Name: dff
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

interface dff_if;
  logic clk;
  logic rst;
  logic din;
  logic q;
  logic qdash;
  
  clocking drv_cb @(negedge clk);
    output rst, din; 
  endclocking
  
  clocking mon_cb @(posedge clk);
    input #0 din, rst, q, qdash; 
  endclocking    
  
endinterface

module dff(dff_if vif);
  
  always @(posedge vif.clk) begin
    if(vif.rst) vif.q<=1'b0;
    else vif.q<=vif.din;
  end
  
  assign vif.qdash=~vif.q;

endmodule
