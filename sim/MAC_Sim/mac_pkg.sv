`include "../CRC_Sim/crc_pkg.sv"

package mac_pkg;

    import crc_pkg::*;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;

    typedef struct packed{
        logic [DATA_WIDTH-1:0]  axis_tdata;
        logic [CTRL_WIDTH-1:0]  axis_tkeep;
        logic                   axis_tlast;
        logic                   axis_tvalid;
    } axi_stream_t;

    typedef struct packed{
        logic [DATA_WIDTH-1:0]  xgmii_data;
        logic [CTRL_WIDTH-1:0]  xgmii_ctrl;
        logic                   xgmii_valid;
    }xgmii_stream_t;

    /* Data Queues */
    axi_stream_t tx_mac_data_queue[$];

    function void generate_tx_data_stream(ref axi_stream_t queue[$]);
        axi_stream_t tx_packet;
        int num_bytes, num_words, remainder_bytes;

        //TODO: Randomize this value
        num_bytes = 62;
        num_words = num_bytes/4;
        remainder_bytes = num_bytes % 4;

        $display("Number of Bytes to output: %0d", num_bytes);

        repeat(num_words) begin
            tx_packet.axis_tdata = $random;
            tx_packet.axis_tkeep = 4'hF;
            tx_packet.axis_tvalid = 1'b1;
            tx_packet.axis_tlast = 1'b0;
            queue.push_front(tx_packet);
        end

        if (remainder_bytes != 0) begin
            tx_packet.axis_tdata = $random;
            tx_packet.axis_tkeep = 0;
            tx_packet.axis_tvalid = 1'b1;
            tx_packet.axis_tlast = 1'b1;

            repeat(remainder_bytes)
                tx_packet.axis_tkeep = {tx_packet.axis_tkeep[2:0], 1'b1};

            queue.push_front(tx_packet);            
        end

    endfunction : generate_tx_data_stream

    function void generate_eth_hdr(ref xgmii_stream_t xgmii_q[$]);

        xgmii_stream_t  xgmii_eth_hdr;

        // Generate first part of eth header + start condition
        xgmii_eth_hdr.xgmii_data = 32'h555555fb;
        xgmii_eth_hdr.xgmii_ctrl = 4'h1;
        xgmii_eth_hdr.xgmii_valid = 1'b1;
        xgmii_q.push_back(xgmii_eth_hdr);

        // Generate Second part of eth header with SFD
        xgmii_eth_hdr.xgmii_data = 32'hd5555555;
        xgmii_eth_hdr.xgmii_ctrl = 4'h0;
        xgmii_eth_hdr.xgmii_valid = 1'b1;
        xgmii_q.push_back(xgmii_eth_hdr);

    endfunction : generate_eth_hdr

    function xgmii_stream_t convert_axi_to_xgmii(axi_stream_t axi_data);

        xgmii_stream_t xgmii;

        xgmii.xgmii_data = axi_data.axis_tdata;
        xgmii.xgmii_valid = 1'b1;

        if (axi_data.axis_tlast) begin
            xgmii.xgmii_ctrl = (axi_data.axis_tkeep == 4'b1111) ? 4'b0 : ~axi_data.axis_tkeep;
        end else begin
            xgmii.xgmii_ctrl = 4'b0;
        end

        return xgmii;

    endfunction : convert_axi_to_xgmii

    function void eth_data_axi_to_xgmii(
        axi_stream_t axi_data[$],
        logic [CRC_WIDTH-1:0] lut [3:0][255:0],
        ref xgmii_stream_t xgmii_q[$]
    );

        int             data_stream_size;
        logic [31:0]    crc;
        axi_stream_t    axi_pkt;
        xgmii_stream_t  xgmii;
        crc_word_t      axi_data_crc;
        crc_word_t      axi_data_crc_q[$];

        // Get size of data stream
        data_stream_size = axi_data.size();

        repeat(data_stream_size) begin
            axi_pkt = axi_data.pop_back();
            xgmii_q.push_back(convert_axi_to_xgmii(axi_pkt));

            // Convert to the CRC Word to pass into referenc model
            axi_data_crc.data_word = axi_pkt.axis_tdata;
            axi_data_crc.data_valid = axi_pkt.axis_tkeep;
            axi_data_crc_q.push_front(axi_data_crc);
        end

        //TODO: Handle Padding here

        // Ca;culate and append CRC to end of XGMII Queue
        crc = crc32_slicing_by_4(axi_data_crc_q, lut);

        $display("CRC Calculated: %0h", crc);

        data_stream_size = xgmii_q.size();

        case(xgmii_q[data_stream_size-1].xgmii_ctrl)
            4'b0000: begin
                xgmii.xgmii_data = crc;
                xgmii.xgmii_ctrl = 4'd0;
                xgmii.xgmii_valid = 1'b1;
                xgmii_q.push_back(xgmii);
            end
            4'b1110: begin
                for(int i = 0; i < 2; i++) begin
                    if (i == 0) begin
                        xgmii_q[data_stream_size-1].xgmii_data[31:8] = crc[23:0];
                        xgmii_q[data_stream_size-1].xgmii_ctrl = 4'b0000;
                        xgmii_q[data_stream_size-1].xgmii_valid = 1'b1;
                    end else begin
                        xgmii.xgmii_data = {{2{8'h07}}, 8'hFD, crc[31:24]};
                        xgmii.xgmii_ctrl = 4'b1110;
                        xgmii.xgmii_valid = 1'b1;
                        xgmii_q.push_back(xgmii);
                    end
                end
            end
            4'b1100: begin
                for(int i = 0; i < 2; i++) begin
                    if (i == 0) begin
                        xgmii_q[data_stream_size-1].xgmii_data[31:16] = crc[15:0];
                        xgmii_q[data_stream_size-1].xgmii_ctrl = 4'b0000;
                        xgmii_q[data_stream_size-1].xgmii_valid = 1'b1;
                    end else begin
                        xgmii.xgmii_data = {8'h07, 8'hFD, crc[31:16]};
                        xgmii.xgmii_ctrl = 4'b1100;
                        xgmii.xgmii_valid = 1'b1;
                        xgmii_q.push_back(xgmii);
                    end
                end
            end     
            4'b1000: begin
                for(int i = 0; i < 2; i++) begin
                    if (i == 0) begin
                        xgmii_q[data_stream_size-1].xgmii_data[31:24] = crc[7:0];
                        xgmii_q[data_stream_size-1].xgmii_ctrl = 4'b0000;
                        xgmii_q[data_stream_size-1].xgmii_valid = 1'b1;
                    end else begin
                        xgmii.xgmii_data = {8'hFD, crc[31:8]};
                        xgmii.xgmii_ctrl = 4'b1000;
                        xgmii.xgmii_valid = 1'b1;
                        xgmii_q.push_back(xgmii);
                    end
                end
            end                      
        endcase        


    endfunction : eth_data_axi_to_xgmii

    //TODO: Return xgmii_stream_t queue
    function void tx_mac_golden_model(
        axi_stream_t axi_data[$], 
        logic [CRC_WIDTH-1:0] lut [3:0][255:0],
        ref xgmii_stream_t xgmii [$]    
    );
        // Generate and append ethernet header + XGMII start condition
        generate_eth_hdr(xgmii);

        // Convert data words to xgmii
        eth_data_axi_to_xgmii(axi_data, lut, xgmii);

        foreach(xgmii[i]) begin
            $display("Data[%0d]: %0h", i, xgmii[i].xgmii_data);
            $display("Ctrl [%0d]: %0h", i, xgmii[i].xgmii_ctrl);
        end

    endfunction : tx_mac_golden_model

endpackage : mac_pkg