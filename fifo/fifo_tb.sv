class transaction;
  
  bit clk, rst, wr, rd;
  logic [7:0] din, dout;
  logic full, empty;
  
  function transaction copy();
    copy=new();
    copy.clk=this.clk;
    copy.rst=this.rst;
    copy.wr=this.wr;
    copy.rd=this.rd;
    copy.din=this.din;
    copy.dout=this.dout;
    copy.full=this.full;
    copy.empty=this.empty;
  endfunction
  
  function display(string dis);
    $display("[%0s] : clk=%0t | rst=%0d | wr=%0d | rd=%0d | din=%0d | dout=%0d | full=%0d | empty=%0d", this.dis, this.clk, this.rst, this.wr, this.rd, this.din, this.dout, this.full, this.empty);
  endfunction
  
endclass
