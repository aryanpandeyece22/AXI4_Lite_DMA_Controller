# AXI4-Lite Master DMA Controller  
A clean, modular Verilog implementation of a Master DMA Controller using the AXI4-Lite protocol.

This repository implements the **I-CHIP PS-1 (Udyam 2025) DMA Controller**, designed to:
- Read a block of data from a source address (AXI-Lite read channel)
- Buffer the data through a 16x32-bit synchronous FIFO
- Write the data to a destination address (AXI-Lite write channel)
- Operate autonomously once triggered by software
- Generate a `done` signal upon transfer completion

The design supports **aligned source/destination addresses**, proper `WSTRB` generation, and AXI-Lite compliant handshaking.

---


---

## 🚀 Features

- Full **AXI4-Lite compliant** master interface
- Separate **read FSM** and **write FSM**
- Internal 16-word FIFO for rate matching
- Byte-level alignment for unaligned transfers
- Clean, synthesizable Verilog
- Works on all FPGA families (Xilinx, Intel)

---

## 🧠 Design Overview

### 1. Read Path
- DMA generates read addresses using AR channel  
- Accepts data via R channel  
- Packs/unpacks bytes for unaligned source addresses  
- Pushes words into FIFO

### 2. FIFO Buffer
- Decouples read & write bandwidth  
- Prevents stalls when write side is slower  
- Standard synchronous FIFO with back-pressure

### 3. Write Path
- Reads from FIFO
- Handles unaligned destination writes using:
  - `WSTRB`
  - data shifting
- Sends write data and address using AW/W channels

### 4. Completion
`done` is asserted when:
