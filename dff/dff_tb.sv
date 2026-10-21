`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/14/2026 08:50:35 PM
// Design Name: 
// Module Name: dff_tb
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

class transaction;

  rand bit din;
  bit rst;
  logic q;
  logic qdash;

  function transaction copy();
    copy=new();
    copy.din=this.din;
    copy.q=this.q;
    copy.qdash=this.qdash;
    copy.rst=this.rst;
  endfunction

  function void display(input string des);
    $display("[%0s] : time = %0t | din = %0d | rst = %0d | q = %0d | ~q = %0d", des, $time, din, rst, q, qdash);
  endfunction

endclass

class generator;

  transaction tr;
  mailbox #(transaction) mbx;
  mailbox #(transaction) mbxref;
  int count;
  event done, sconext;


  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref, input event done, input event sconext);
    this.mbx=mbx;
    this.mbxref=mbxref;
    this.done=done;
    this.sconext=sconext;
    tr=new();
  endfunction

  task run();
    /*
    repeat(count) begin 
      assert(tr.randomize()) else $display("[GEN] : Randomization Failed");
      tr.display("GEN");
      mbx.put(tr.copy);
      mbxref.put(tr.copy);
      @(sconext);
    end
    ->done;
    */
    for(int i=0; i<count; i++) begin
      assert(tr.randomize()) else $display("[GEN] : Randomization Failed");
      if(i==0||i==1||i==4||i==5) tr.rst=1'b1;
      else tr.rst=1'b0;
      tr.display("GEN");
      mbx.put(tr.copy);
      mbxref.put(tr.copy);
      @(sconext);  
    end
    ->done;
  endtask

endclass

class driver;

  transaction dc;
  mailbox #(transaction) mbx;
  virtual dff_if vif;

  function new(mailbox #(transaction) mbx, virtual dff_if vif);
    this.mbx=mbx;
    this.vif=vif;
  endfunction
/*
  task reset();
    @(vif.drv_cb);
    vif.drv_cb.rst<=1'b1;
    repeat(2)@(posedge vif.clk);
    @(vif.drv_cb);
    vif.drv_cb.rst<=1'b0;
  endtask
*/
  task run();
    forever begin
      @(vif.drv_cb);
      mbx.get(dc);
      vif.drv_cb.din<=dc.din;
      vif.drv_cb.rst<=dc.rst;
      dc.display("DRV");
    end
  endtask

endclass

class monitor;

  virtual dff_if vif;
  transaction tr;
  mailbox #(transaction) mbxsco;

  function new(mailbox #(transaction) mbxsco, virtual dff_if vif);
    this.mbxsco=mbxsco;
    this.vif=vif;
    tr=new();
  endfunction

  task run();
    forever begin
      @(vif.mon_cb);
      tr.din=vif.mon_cb.din;
      tr.q=vif.mon_cb.q;
      tr.qdash=vif.mon_cb.qdash;
      tr.rst=vif.mon_cb.rst;
      tr.display("MON");
      mbxsco.put(tr.copy);
    end
  endtask

endclass

class scoreboard;

  mailbox #(transaction) mbxsco;
  mailbox #(transaction) mbxref;
  transaction t;
  transaction r;
  event sconext;
  int success=0, total=0;

  function new(mailbox #(transaction) mbxsco, mailbox #(transaction) mbxref, input event sconext);
    this.mbxsco=mbxsco;
    this.mbxref=mbxref;
    this.sconext=sconext;
  endfunction

  task run();
    forever begin
      mbxref.get(r);
      mbxsco.get(t);
      t.display("SCO");
      total++;
      if(t.rst) begin
        if(t.q==1'b0 && t.qdash==1'b1) begin
          $display ("DATA MATCHED");
          success++;
        end
        else begin
          if(t.q!==1'b0) $display("Q DATA MISMATCHED");
          if(t.qdash!==1'b1) $display("~Q DATA MISMATCHED");
        end
      end
      else begin
        if(t.q==r.din && t.qdash==(~r.din)) begin
          $display("DATA MATCHED");
          success++;
        end
        else begin
          if(t.q!==r.din) $display("Q DATA MISMATCHED");
          if(t.qdash!==(~r.din)) $display("~Q DATA MISMATCHED");
        end
      end
      $display("-----------------------------------------------");
      ->sconext;
    end
  endtask

endclass

class enviro;

  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  event done, sconext, all_done;
  mailbox #(transaction) mbx;
  mailbox #(transaction) mbxref;
  mailbox #(transaction) mbxsco;
  virtual dff_if vif;

  function new(virtual dff_if vif, input event all_done);
    mbx=new();
    mbxref=new();
    mbxsco=new();
    gen=new(mbx, mbxref, done, sconext);
    drv=new(mbx, vif);
    mon=new(mbxsco, vif);
    sco=new(mbxsco, mbxref, sconext);
    this.all_done=all_done;
    this.vif=vif;
  endfunction

  task pre_test();
    vif.din=0;
    vif.rst=0;
  endtask

  task test();
    fork
      //drv.reset();
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask

  task post_test();
    wait(done.triggered);
    #5;
    $display("SUCCESS : %0d out of %0d ", sco.success, sco.total);
    ->all_done;
  endtask

  task run();
    pre_test();
    test();
    post_test();
 endtask

endclass

module dff_tb();
  dff_if vif();
  dff dut(vif);
  event all_done;
  enviro env;
  reg past_valid;
  
  covergroup cg @(posedge vif.clk);
    option.per_instance=1;
    dincg: coverpoint vif.din{
      bins din_zero={0};
      bins din_one={1};
    }
    rstcg: coverpoint vif.rst{
      bins rst_zero={0};
      bins rst_one={1};
      bins zero_to_one=(0=>1);
      bins one_to_zero=(1=>0);
    }
    cross dincg, rstcg;
  endgroup
  
  
  
  cg cov;

  initial past_valid=1'b0;
  
  initial vif.clk=0;
  
  always #10 vif.clk=~vif.clk;

  initial begin
    cov=new();
  end
  
  initial begin
    env=new(vif, all_done);
    env.gen.count=10;
    env.run();
  end

  always @(posedge vif.clk) past_valid<=1'b1;

  assert property (@(posedge vif.clk) past_valid && $past(vif.rst) |-> (vif.q==1'b0));
    
  assert property (@(posedge vif.clk) past_valid && $past(~vif.rst) |-> (vif.q==$past(vif.din)));
  
  assert property (@(posedge vif.clk) past_valid |-> vif.q == (~vif.qdash));
        
  initial begin
    @(all_done);
    #10;
    $finish;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end


endmodule
