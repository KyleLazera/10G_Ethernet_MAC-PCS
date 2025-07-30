# 10G_Ethernet_MAC-PCS

## Table of Contents
 - [Project Motivation](#project-motivation)
 - [Design Overview](#design-overview)
    - [10Gbps Throughput](#10gbps-throughput)
    - [Low-Latency Design](#low-latency-design)
        - [Encoder Design](#encoder-design)
        - [GearBox Design](#gearbox-design)

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

#### Encoder Design

With this in mind, the encoder will receive 32-bit data blocks and 4 bits of control data over the XGMII interface, operating at approximately 322 MHz. However, the encoder must produce 64-bit encoded blocks with a 2-bit header for 64b/66b encoding.

A naive approach would be to output 64-bit blocks at 322 MHz to the scrambler, but this would unintentionally double the throughput. Another option might be to cross clock domains within the encoder: receive data at 322 MHz and transmit 64-bit encoded blocks at ~161 MHz:

Clock Frequency = 10.3125 Gbps / 64 bits ≈ 161 MHz

However, this would introduce additional latency due to the clock domain crossing (CDC), which is undesirable for a low-latency design.
Instead, a more efficient solution is to design the encoder to operate entirely at 322 MHz using 32-bit input and output blocks. While this increases logic complexity slightly compared to a pure 64-bit datapath, it eliminates unnecessary latency caused by CDC and keeps the entire data path running synchronously, ensuring a low-latency, high-speed design.

### Gearbox Design

In digital logic, a gearbox is a device that is used to translate data of different widths between two different modules. This is necessary for the design due to the PCS interface with the GTY transceiver. Currently, the output of the PCS up to this point (output of the encoding block + scrambler) is a 66-bit wide signal. This is an issue, however, as the Ultrascale GTY transceiver IP only permits data widths of 16, 20, 32, 40, 64, 80, 128, or 160 bits. To achieve the width conversion, there are two main design options: an asynchronous gearbox or a synchronous gearbox.

#### Asynchronous Gearbox

Asynchronous gearboxes solves the width conversion issue by implementing a buffer and crossing clock domains to ensure the throughput reamins correct for the output width. As an example for this specific design, we could use a buffer that inputs data at 32 bits per clock cycle with a clock frequency of 322 MHz. Additionally, taking into account the synchronous header, we are able to input 66 bits every 2 clock cycles. Depending on the output width we then want to achieve, we can calculate the output clock rate and pull the specified amount of data from the buffer at that rate.

As an example, if we were using a 64-bit output width, we can calculate:

Clock Frequency = 10.3125 Gbps / 64 bits ≈ 161 MHz

Therefore, every 6.2ns (length of 2 clock cycles at frequency 322MHz) we will write in 66 bits of data and every 6.2ns (length of 1 clock period for 161MHz) we will read out 64 bits of data.

This design has two major downfalls. Firstly, it requires a clock domain crossing, which incurs extra latency into the design and goes against one of the design goals. Additionally, because data is being written into the buffer faster than it is being read out (66 bits in for every 64 bits out), the risk of buffer overflow does exist, even though in this case, it is minimal due to only a 2-bit increase.

#### Synchronous Gearbox
