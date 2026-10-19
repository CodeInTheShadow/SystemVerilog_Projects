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
  
  task run;
    forever begin
      mbxgd.get(dc);
      @(fif.drv_cb);
      fif.drv_cb.rst=dc.rst;
      fif.drv_cb.rd=dc.rd;
      fif.drv_cb.wr=dc.wr;
      fif.drv_cb.din=dc.din;
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
  event next;
  
  function new(mailbox #(transaction) mbxms, event next);
    this.mbxms=mbxms;
    this.next=next;
  endfunction
  
  task run();
    forever begin
      mbxms.get(trans);
      
      -> next;
    end
  endtask
endclass
