# SystemVerilog Design & Verification Portfolio

A repository documenting my implementation and verification of digital hardware blocks using SystemVerilog, featuring layered testbench architectures (Transaction, Generator, Driver, Monitor, Scoreboard), interface blocks, SVA assertions, and functional coverage.

## Implemented Blocks
1. **D Flip-Flop (DFF)**
   - **Design:** Synchronous reset, data capture, and inverted output (`qdash`).
   - **Verification:** Layered testbench with transaction-based generation, mailboxes, scoreboard checking, SystemVerilog Assertions (SVA), and covergroups.
2. **Synchronous FIFO** *(In Progress)*
   - **Design:** Parameterized depth/width memory array with full/empty flags and pointer logic.
   - **Verification:** Layered testbench architecture.

## 📁 Repository Structure
```text
SystemVerilog_Projects/
│
├── README.md
├── dff/
│   ├── dff.sv          
│   └── dff_tb.sv
│
└── fifo/
    ├── fifo.sv       
    └── fifo_tb.sv
```
