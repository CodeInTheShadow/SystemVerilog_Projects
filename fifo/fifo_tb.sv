class transaction;
  
  bit rst; 
  rand bit wr, rd;
  rand logic [7:0] din;
  logic [7:0] dout;
  logic full, empty;
  
  function transaction copy();
    copy=new();
    copy.rst=this.rst;
    copy.wr=this.wr;
    copy.rd=this.rd;
    copy.din=this.din;
    copy.dout=this.dout;
    copy.full=this.full;
    copy.empty=this.empty;
  endfunction
  
  function void display(string dis);
    $display("[%0s] : rst=%0d | wr=%0d | rd=%0d | din=%0d | dout=%0d | full=%0d | empty=%0d", dis, this.rst, this.wr, this.rd, this.din, this.dout, this.full, this.empty);
  endfunction
  
endclass

class generator;
  
  transaction tr;
  mailbox #(transaction) mbxgd;
  int count;
  event done;
  event next;
  
  function new(mailbox #(transaction) mbxgd, event done, event next);
    tr=new();
    this.mbxgd=mbxgd;
    this.done=done;
    this.next=next;
  endfunction
  
  task run;
    repeat (count) begin
      assert (tr.randomize()) else $display("Randomization Failed.");
      tr.display("GEN");
      mbxgd.put(tr.copy());
      @(next);
    end
    ->done;
  endtask
  
endclass

class driver;
  
  transaction dc;
  mailbox #(transaction) mbxgd;
  virtual fifo_if fif;
  
  function new(mailbox #(transaction) mbxgd, virtual fifo_if fif);
    this.mbxgd=mbxgd;
    this.fif=fif;
  endfunction
  
  task reset();
    @(fif.drv_cb);
    fif.drv_cb.rst<=1'b1;
    repeat(2)@(posedge vif.clk);
    @(fif.drv_cb);
    fif.drv_cb.rst<=1'b0;
    #40;
    @(fif.drv_cb);
    fif.drv_cb.rst<=1'b1;
    @(fif.drv_cb);
    fif.drv_cb.rst<=1'b0;
  endtask
  
  task run;
    forever begin
      mbxgd.get(dc);
      @(fif.drv_cb);
      fif.drv_cb.rst<=dc.rst;
      fif.drv_cb.rd<=dc.rd;
      fif.drv_cb.wr<=dc.wr;
      fif.drv_cb.din<=dc.din;
      dc.display("DRV");
    end
  endtask
  
endclass


class monitor;
  
  transaction tr;
  mailbox #(transaction) mbxms;
  virtual fifo_if fif;
  
  function new(mailbox #(transaction) mbxms, virtual fifo_if fif);
    this.mbxms=mbxms;
    this.fif=fif;
  endfunction
  
  task run();
    forever begin
      @(fif.mon_cb);
      tr=new();
      tr.rst=fif.mon_cb.rst;
      tr.rd=fif.mon_cb.rd;
      tr.wr=fif.mon_cb.wr;
      tr.din=fif.mon_cb.din;
      tr.empty=fif.mon_cb.empty;
      tr.full=fif.mon_cb.full;
      tr.dout=fif.mon_cb.dout;
      mbxms.put(tr.copy());
      tr.display("MON");
    end
  endtask
  
endclass

class scoreboard;
  
  transaction trans;
  mailbox #(transaction) mbxms;
  bit [7:0] mem[$:15];
  bit [7:0] out;
  bit em, fu;
  bit pf;
  int count=0, d=0, e=0, f=0, total=0;
  event next;
  
  function new(mailbox #(transaction) mbxms, event next);
    this.mbxms=mbxms;
    this.next=next;
  endfunction
  
  task run();
    forever begin
      mbxms.get(trans);
      pf=1'b0;
      total++;
      //reference model
      if (trans.rst) begin
        mem.delete();
        out=8'b00000000;
      end
      else if (trans.rd && trans.wr && (mem.size()==16)) begin
        out=mem.pop_front();
        mem.push_back(trans.din);
      end
      else if (trans.rd && trans.wr && (mem.size()==0)) begin
        mem.push_back(trans.din);
      end
      else if (trans.rd && trans.wr && (mem.size()!==16) && (mem.size()!==0)) begin
        out=mem.pop_front();
        mem.push_back(trans.din);
      end
      else if (trans.wr && (mem.size()!==16)) begin
        mem.push_back(trans.din);
      end
      else if (trans.rd && (mem.size()!==0)) begin
        out=mem.pop_front();
      end
      
      //empty flag
      if (mem.size()==0) em=1'b1;
      else em=1'b0;
      
      //full flag
      if (mem.size()==16) fu=1'b1;
      else fu=1'b0;
      
      
      
      //dout check
      if (out!==trans.dout) begin
        $display("DOUT MISMATCH. Expected Value:%0d, Actual Value: %0d", out, trans.dout);
        
        pf=1'b1;
      end
      else d++;
      
      //empty flag check
      if (em!==trans.empty) begin
        $display("EMPTY FLAG MISMATCH. Expected Value:%0d, Actual Value: %0d", em, trans.empty);
        pf=1'b1;
      end
      else e++;
      
      //full flag check
      if (fu!==trans.full) begin
        $display("FULL FLAG MISMATCH. Expected Value:%0d, Actual Value: %0d", fu, trans.full);
        pf=1'b1;
      end
      else f++;
      
      if(pf==0) begin
        $display("ALL CHECKS PASSED.");
        count++;
      end
      $display("-----------------------------------------");
      -> next;
    end
  endtask
endclass

class enviroment;
  
  transaction tr;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) mbxgd, mbxms;
  event done, next, done_all;
  virtual fifo_if fif;
  
  function new(virtual fifo_if fif, event done_all);
    mbxgd=new();
    mbxms=new();
    tr=new();
    gen=new(mbxgd, done, next);
    drv=new(mbxgd, fif);
    mon=new(mbxms, fif);
    sco=new(mbxms, next);
    this.done_all=done_all;
    this.fif=fif;
  endfunction
  
  task pre_test;
    fif.rd<=1'b0;
    fif.wr<=1'b0;
    fif.din<=8'b00000000;
  endtask
  
  task test();
    fork
      drv.reset();
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    $display("DOUT TEST : %0d/%0d SUCCESSFUL CASES", sco.d, sco.total);
    $display("EMPTY FLAG TEST : %0d/%0d SUCCESSFUL CASES", sco.e, sco.total);
    $display("FULL FLAG TEST : %0d/%0d SUCCESSFUL CASES", sco.f, sco.total);
    $display("OVERALL TEST : %0d/%0d SUCCESSFUL CASES", sco.count, sco.total);
    ->done_all;
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb;
  
  environment env;
  event done_all;
  fifo_if fif();
  dut fifo(fif);
  
  initial begin
    env=new(fif, done_all);
    env.gen.count=10;
    env.run();
  end
  
  initial begin
    @(done_all);
    $finish;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
endmodule
