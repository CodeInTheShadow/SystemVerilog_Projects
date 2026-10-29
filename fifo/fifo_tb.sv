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
    $display("[%0s] : time=%0t | rst=%0d | wr=%0d | rd=%0d | din=%0d | dout=%0d | full=%0d | empty=%0d", dis, $time, this.rst, this.wr, this.rd, this.din, this.dout, this.full, this.empty);
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
    dc=new();
  endfunction
  
  task reset();
    dc.rst<=1'b1;
    @(fif.drv_cb);
    fif.drv_cb.rst<=dc.rst;
    dc.display("RESET");
    @(fif.drv_cb);
    dc.display("RESET");
    dc.rst<=1'b0;
    @(fif.drv_cb);
    fif.drv_cb.rst<=dc.rst;
    dc.display("RESET");
    /*
    #40;
    @(fif.drv_cb);
    fif.drv_cb.rst<=1'b1;
    @(fif.drv_cb);
    fif.drv_cb.rst<=1'b0;
    */
  endtask
  
  task run;
    forever begin
      mbxgd.get(dc);
      @(fif.drv_cb);
      //fif.drv_cb.rst<=dc.rst;
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
  logic [7:0] mem[$:15];
  logic [7:0] out;
  bit em, fu;
  bit pf;
  int size;
  int count=0, d=0, e=0, f=0, total=0;
  event next;
  
  function new(mailbox #(transaction) mbxms, event next);
    this.mbxms=mbxms;
    this.next=next;
    trans=new();
  endfunction
  
  task run();
    forever begin
      mbxms.get(trans);
      pf=1'b0;
      size=mem.size();
      total++;
      //reference model
      if (trans.rst) begin
        mem.delete();
        out=8'b00000000;
      end
      else if (trans.rd && trans.wr && (size==16)) begin
        out=mem.pop_front();
        mem.push_back(trans.din);
      end
      else if (trans.rd && trans.wr && (size==0)) begin
        mem.push_back(trans.din);
      end
      else if (trans.rd && trans.wr && (size!=16) && (size!=0)) begin
        out=mem.pop_front();
        mem.push_back(trans.din);
      end
      else if (trans.wr && (size!=16)) begin
        mem.push_back(trans.din);
      end
      else if (trans.rd && (size!=0)) begin
        out=mem.pop_front();
      end
      
      size=mem.size();
      
      //empty flag
      if (size==0) em=1'b1;
      else em=1'b0;
      
      //full flag
      if (size==16) fu=1'b1;
      else fu=1'b0;
      
      trans.display("SCO");
      
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

class environment;
  
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
  /*
  task pre_test;
    fif.rd<=1'b0;
    fif.wr<=1'b0;
    fif.din<=8'b00000000;
  endtask
  */
  task directed_test();
    //full
    for(int i=0; i<17; i++) begin
      tr.rd=1'b0;
      tr.wr=1'b1;
      tr.din=i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    for(int i=0; i<2; i++) begin
      tr.rd=1'b1;
      tr.wr=1'b1;
      tr.din=100+i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    //empty
    for(int i=0; i<17; i++) begin
      tr.rd=1'b1;
      tr.wr=1'b0;
      tr.din=i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    for(int i=0; i<2; i++) begin
      tr.rd=1'b1;
      tr.wr=1'b1;
      tr.din=100+i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    //fill partially
    for(int i=0; i<4; i++) begin
      tr.rd=1'b0;
      tr.wr=1'b1;
      tr.din=i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    for(int i=0; i<2; i++) begin
      tr.rd=1'b1;
      tr.wr=1'b1;
      tr.din=100+i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    //wrap around
    for(int i=0; i<1; i++) begin
      tr.rst=1'b1;
      tr.rd=1'b0;
      tr.wr=1'b0;
      mbxgd.put(tr.copy());
      tr.display("RESET");
      @(next);
    end
    for(int i=0; i<1; i++) begin
      tr.rst=1'b0;
      mbxgd.put(tr.copy());
      tr.display("RESET");
      @(next);
    end
    for(int i=0; i<12; i++) begin
      tr.rd=1'b0;
      tr.wr=1'b1;
      tr.din=i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    for(int i=0; i<10; i++) begin
      tr.rd=1'b1;
      tr.wr=1'b0;
      tr.din=i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    for(int i=0; i<10; i++) begin
      tr.rd=1'b0;
      tr.wr=1'b1;
      tr.din=i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    for(int i=0; i<12; i++) begin
      tr.rd=1'b1;
      tr.wr=1'b0;
      tr.din=i;
      mbxgd.put(tr.copy());
      tr.display("DIRECTED");
      @(next);
    end
    ->done;
  endtask
  
  task test();
    fork
      begin
        drv.reset();
        #15;
        fork
          //gen.run();
          directed_test();
          drv.run();
        join_any
      end
      mon.run();
      sco.run();
    join_any
    disable fork;
  endtask
  
  task post_test();
    $display("DOUT TEST : %0d/%0d SUCCESSFUL CASES", sco.d, sco.total);
    $display("EMPTY FLAG TEST : %0d/%0d SUCCESSFUL CASES", sco.e, sco.total);
    $display("FULL FLAG TEST : %0d/%0d SUCCESSFUL CASES", sco.f, sco.total);
    $display("OVERALL TEST : %0d/%0d SUCCESSFUL CASES", sco.count, sco.total);
    ->done_all;
  endtask
  
  task run();
    //pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb;
  
  environment env;
  event done_all;
  fifo_if fif();
  fifo dut(.clk(fif.clk), .rst(fif.rst), .rd(fif.rd), .wr(fif.wr), .din(fif.din), .full(fif.full), .empty(fif.empty), .dout(fif.dout));
  
  initial fif.clk=1'b0;
  
  always #10 fif.clk=~fif.clk;
  
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
