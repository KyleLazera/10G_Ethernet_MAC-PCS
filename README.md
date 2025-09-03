# 10G_Ethernet_MAC-PCS

## Table of Contents
 - [Project Motivation](#project-motivation)
 - [Design Overview](#design-overview)
    - [10Gbps Throughput](#10gbps-throughput)
    - [Low-Latency Design](#low-latency-design)
 - [Module Designs](#module-designs)
     - [TX Encoder](#tx-encoder)
     - [TX GearBox](#tx-gearbox)
     - [RX Gearbox](#rx-gearbox)
        - [Re-Aligning Data](#re-aligning-data)
        - [Re-Aligning Algorithm](#re-aligning-algorithm)

## Project Motivation
This project serves as an extension of the UDP/IP Ethernet stack I developed in a previous project:  
[https://github.com/KyleLazera/udp-ip-mac-core](https://github.com/KyleLazera/udp-ip-mac-core)

In that project, I designed a 1G Ethernet MAC connected to a low-latency UDP/IP stack to encapsulate and de-encapsulate data within a network packet.

In this follow-up project, my goal is to delve deeper into two key areas:

1. The Physical Coding Sublayer (PCS) within Ethernet  
2. Low-latency, high-speed interfaces

By the end of this project, I aim to gain a deeper understanding of 10G Ethernet—specifically 64b/66b encoding, scrambling, and the development of a gearbox to interface with GTY transceivers.

Due to the lack of a development board that supports 10G Ethernet, the project will focus only on implementation and design verification. I will ensure that the design meets timing requirements, although I will not have the opportunity to test it on physical hardware.

## Design Overview
The overall goal of this design is to implement a 10G Ethernet MAC/PCS with minimal latency per byte of data. A diagram of the overall design
is depicted below.

![10G Ethernet Diagram](<10G Ethernet.jpg>)

### 10Gbps Throughput

A fundamental requirement of this design is achieving a throughput of 10 Gbps—that is, transmitting 10 gigabits of data every second. While this may seem straightforward, it is complicated by the mandatory use of 64b/66b encoding, as specified by the IEEE 802.3-2012 standard for 10G Ethernet.

This encoding scheme takes 64-bit data blocks and prepends a 2-bit synchronous header, resulting in a 66-bit frame. The header indicates whether the frame contains data or control information.

Because only 64 out of every 66 bits are actual data, 64b/66b encoding incurs a 3.125% overhead. This means that 3.125% of the transmitted bits are used for synchronization rather than payload, which reduces the effective data rate.

To compensate for this and maintain an effective throughput of 10 Gbps, we must calculate the necessary line rate using the following relationship:

    Total Throughput = (Line Rate) * 64/66

Solving for the required line-rate:

    Line Rate = 10 Gbps × (66 / 64) = 10.3125 Gbps

Therefore, to achieve a true 10 Gbps data throughput with 64b/66b encoding, the Ethernet line must operate at 10.3125 Gbps.

### Low-Latency Design

Given the required line rate of 10.3125 Gbps, a critical design consideration was how the components within the MAC and PCS would interface with one another. In this architecture, the MAC connects to the PCS (Physical Coding Sublayer) via the XGMII interface — a simple, parallel bus consisting of 32 bits of payload data and 4 bits of control data.

Using this bus width, we can determine the required clock frequency to achieve 10.3125 Gbps throughput with the following equation:

    Clock Frequency = Desired Throughput / Data Width

Therefore:

    10.3125Gbps/32 = ~322MHz

## Module Designs

This section provides an overview of each module used within the 10G Ethernet design and goes over the design challenges associated with each.

## TX Encoder

With this in mind, the encoder will receive 32-bit data blocks and 4 bits of control data over the XGMII interface, operating at approximately 322 MHz. However, the encoder must produce 64-bit encoded blocks with a 2-bit header for 64b/66b encoding.

A naive approach would be to output 64-bit blocks at 322 MHz to the scrambler, but this would unintentionally double the throughput. Another option might be to cross clock domains within the encoder: receive data at 322 MHz and transmit 64-bit encoded blocks at ~161 MHz:

Clock Frequency = 10.3125 Gbps / 64 bits ≈ 161 MHz

However, this would introduce additional latency due to the clock domain crossing (CDC), which is undesirable for a low-latency design.
Instead, a more efficient solution is to design the encoder to operate entirely at 322 MHz using 32-bit input and output blocks. While this increases logic complexity slightly compared to a pure 64-bit datapath, it eliminates unnecessary latency caused by CDC and keeps the entire data path running synchronously, ensuring a low-latency, high-speed design.

## TX Gearbox 

In this project, a 32-bit data path is used to move data through the Physical Coding Sublayer (PCS) and into the gearbox. However, the 10GBASE-R specification defines its data format in terms of 66-bit blocks, each composed of a 2-bit synchronization header followed by 64 bits of payload data.

Since our internal data path is only 32 bits wide, a single 66-bit block must be transmitted over multiple clock cycles. This creates a misalignment between the block boundary and the word boundary, which cannot be resolved without additional logic.

The 66-bit block is split across three 32-bit cycles as follows:

    Cycle 1: Contains the 2-bit sync header + first 30 bits of payload

    Cycle 2: Contains the remaining 34 bits of payload (2 bits from previous payload + 30 new bits)

    Cycle 3: Contains the final 2 bits of the current 66-bit block + 2-bit header of the next block + 28 bits of new payload

This overlapping of blocks across cycles introduces data misalignment, which is why a gearbox is required.

The gearbox acts as a realignment buffer, collecting consecutive 32-bit input words and reassembling them into correctly aligned 66-bit blocks. This ensures that the serialized output to the transceiver consists of valid, properly framed 66-bit words, each containing exactly one sync header and one payload.


#### Asynchronous Gearbox

Asynchronous gearboxes solves the width conversion issue by implementing a buffer and crossing clock domains to ensure the throughput reamins correct for the output width. As an example for this specific design, we could use a buffer that inputs data at 32 bits per clock cycle with a clock frequency of 322 MHz. Additionally, taking into account the synchronous header, we are able to input 66 bits every 2 clock cycles. Depending on the output width we then want to achieve, we can calculate the output clock rate and pull the specified amount of data from the buffer at that rate.

As an example, if we were using a 64-bit output width, we can calculate:

Clock Frequency = 10.3125 Gbps / 64 bits ≈ 161 MHz

Therefore, every 6.2ns (length of 2 clock cycles at frequency 322MHz) we will write in 66 bits of data and every 6.2ns (length of 1 clock period for 161MHz) we will read out 64 bits of data.

This design has a major downfall in that it requires a clock domain crossing, which incurs extra latency into the design and goes against one of the design goals. 

#### Synchronous Gearbox

The synchronous gearbox performs width conversion without involving a clock domain crossing, meaning both the input and output clock domains operate at the same frequency. However, a subtle issue arises: while the clocks are synchronized, the input data rate is slightly higher than the output data rate due to protocol overhead—a 2-bit header is inserted every other cycle. Every two clock cycles, the gearbox receives two 32-bit data words and one 2-bit header, totaling 66 bits over 2 cycles.

Input throughput:  
`66 bits / 2 cycles = 33 bits per cycle`

Output throughput:  
`32 bits per cycle`

Using both of these throughput calculations, we can determine the input-to-output ratio of the gearbox.

Input-to-output ratio:  
`33 bits : 32 bits`

This means for every 32-bit word transmitted from the gearbox, there will be 1 bit of extra data left over from the input. Without control logic, this excess would accumulate indefinitely, which is not feasible. However, since this discrepancy adds 1 extra bit per cycle, after 32 cycles, a full 32-bit word accumulates. The solution is to apply backpressure from the gearbox to the Encoder and MAC every 32 cycles. This backpressure halts the transmission of new data momentarily, allowing the gearbox to transmit the extra 32-bit word and maintain synchronization.

## RX Gearbox

The RX gearbox is similar in function to the TX gearbox but includes an additional complication. Like the TX gearbox, it receives data from the transceivers in **32-bit words**, but it must ensure the data is correctly reassembled in **64b/66b block format**.

A 64b/66b block is structured as follows:

| Bit #  | 0  | 1  | 2  | 3  | 4  | ... | 65  |
|--------|----|----|----|----|----|-----|-----|
| Field  | H0 | H1 | D0 | D1 | D2 | ... | D63 |

Here, **H0:H1** represents the 2-bit synchronous header, and **D0–D63** represents the 64-bit payload.

Since the RX gearbox receives **32-bit chunks**, a single 66-bit block is split across multiple words:

1. **First 32-bit word:** `[H0:H1, D0:D29]`  
2. **Second 32-bit word:** `[D30:D61]`  
3. **Third 32-bit word:** `[D62:D63, H0:H1 (next block), D0:D27]`  

Notice that the third word contains the **remaining 2 bits from the first 66-bit block** as well as the **beginning of the next block**.

The primary goal of the RX gearbox is to **correctly capture the synchronous header and payload**, ensuring data is properly aligned before passing it to the **de-scrambler and decoder**.

### Re-Aligning Data

A key challenge for the RX gearbox is that we cannot assume the first 32-bit word is aligned with the start of a 66-bit block (i.e., `[H0:H1, D0:D29]`). Depending on when the PCS receives data from the PMA, the RX gearbox may start mid-block, resulting in misalignment. If the gearbox begins receiving data in the middle of a 66-bit block, the first 32-bit word may not contain the header (`H0:H1`) and the expected first data bits (`D0:D29`). Without re-alignment, the gearbox would misinterpret data, causing errors in the de-scrambler and decoder. The purpose of re-alignment is to detect the correct position of the 66-bit synchronous header and shift incoming 32-bit words so that the 64b/66b blocks are correctly reconstructed.

Suppose the correct 66-bit block looks like this:

[ H0 H1 | D0 D1 D2 ... D61 D62 D63 ]

But the RX gearbox may begin capturing in the middle of the block, producing 32-bit words that cut across boundaries:

Word 1: D45 D46 D47 ... D63 H0 H1 D0 D1 D2 D3 ...
Word 2: D12 D13 D14 ... D43 D44
Word 3: D45 D46 D47 ... (repeats misaligned pattern)

Here, the header bits `H0 H1` are not at the start of a word, but instead appear inside `Word 1`. If we attempted to decode immediately, the deserializer would treat `D45 D46` as the header, which is invalid.

The gearbox must therefore realign so that every 32-bit word is grouped such that:

[ H0 H1 | D0 ... D29 ] [ D30 ... D61 D62 D63 | H0 H1 | D0 ... ]

This ensures that the 66-bit boundaries are respected and blocks are reconstructed properly.

### Re-Aligning Algorithm

#### Conceptual Idea

Conceptually, aligning data in the RX gearbox can be thought of as managing a continuous bit stream.  
The incoming data is serialized and then captured in 32-bit words, which are fed into the gearbox.  

We can imagine a sliding window of 32 bits moving along this bit stream. Each time the window moves, it captures a 32-bit word and passes it to the gearbox.  

If the data is misaligned (e.g., the synchronous 2-bit header `[H0:H1]` is not at the correct boundary), we can correct this by shifting the sliding window one bit at a time to the left. This process continues until the gearbox finds the valid 66-bit header position, ensuring the data blocks are reconstructed properly.

Continuous Bit Stream:
... H0 H1 D0 D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 D12 D13 ...

Initial Window (32 bits, misaligned):
[ D4 D5 D6 D7 D8 D9 D10 D11 D12 D13 D14 ... D35 ]

Shift Left by 1 Bit:
[ D5 D6 D7 D8 D9 D10 D11 D12 D13 D14 ... D36 ]

Shift Left by 1 Bit:
[ D6 D7 D8 D9 D10 D11 D12 D13 D14 ... D37 ]

...
After Enough Shifts → Header Detected:
[ H0 H1 D0 D1 D2 D3 ... D29 D30 D31 ]

In this example, the window begins in the middle of the block (misaligned) but is repeatedly shifted left until the `H0 H1` header is correctly aligned at the start of the 32-bit word. Once the gearbox detects this alignment, normal block reconstruction can begin.

#### Implementation 

While the conceptual example above is straightforward, implementing the logic is more challenging because the datapath only provides 32 bits at a time. To avoid introducing unnecessary latency, we cannot pause the gearbox simply to buffer additional data.

My first approach was to implement a bit-by-bit slip algorithm, shifting the 66-bit buffer by one position whenever required. However, this quickly led to bugs and excessive complexity, especially when running at 322 MHz. The design had to account for numerous edge cases, such as ensuring that data validity aligned with the number of slips received.

For example, using the index lookup table (LUT) to place data, we see that on cycle 32 and cycle 33, incoming data is inserted at indices 2 and 34, respectively. If the system slips by three positions, the sync header should now be checked at positions [4:3] of the 66-bit buffer. However, on cycle 32, incoming data would be written into positions [33:2], while the decoder attempts to read positions [34:3]. This creates a subtle but significant issue: bit 34 being sampled comes from two cycles earlier because it was never updated. Although solutions were possible, each fix added more complexity, making the design increasingly fragile.

Instead, I adopted a more efficient approach that leveraged the existing index lookup table, which already controls where incoming data is written. Observing the LUT revealed that the insertion index decreases by two bits per cycle. This insight led to a simplified algorithm:

Treat every two slip signals as equivalent to halting the sequence counter for one cycle.

For an odd number of slips, adjust the sync header sampling by one bit (e.g., check [2:1] instead of [1:0]).

With this scheme, each slip signal instructs the system to temporarily halt the counter and overwrite the previously written word, effectively discarding the misaligned data. This naturally implements a 2-bit slip, so alignment only needs to be corrected on every second slip received.

This method eliminates the need for complex bit-shifting logic while maintaining reliable synchronization at high speed. A software model of this algorithm is available in Software/rx_sync_alo, which demonstrates and validates the approach.