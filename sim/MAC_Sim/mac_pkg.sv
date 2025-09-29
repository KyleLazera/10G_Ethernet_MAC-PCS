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

    function int generate_tx_data_stream(ref axi_stream_t queue[$]);
        axi_stream_t tx_packet;
        int num_bytes, num_words, remainder_bytes;

        //TODO: Randomize this value
        num_bytes = 56;
        num_words = num_bytes/4;
        remainder_bytes = num_bytes % 4;

        for(int i = 0; i < num_words; i++) begin
            tx_packet.axis_tdata = $random;
            tx_packet.axis_tlast = 1'b0;
            tx_packet.axis_tkeep = 4'hF;
            tx_packet.axis_tvalid = 1'b1;

            // Only set tlast here if the num_bytes is perfectly divisible by 4 (4 bytes = 32 bits)
            if (i == (num_words - 1))
                tx_packet.axis_tlast = (remainder_bytes == 0);

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

        return num_bytes;

    endfunction : generate_tx_data_stream

    function automatic void tx_mac_ref_model(
        axi_stream_t axi_data[$], 
        logic [CRC_WIDTH-1:0] lut [3:0][255:0],
        ref xgmii_stream_t xgmii [$]    
    );

        typedef enum {
            HEADER,
            DATA,
            PADDING,
            CRC,
            TERMINATE,
            IFG,
            COMPLETE
        } state_t;

        state_t                     state = HEADER;
        logic [(2*DATA_WIDTH)-1:0]  data_shift_reg;
        logic [(2*CTRL_WIDTH)-1:0]  ctrl_shift_reg;
        logic [DATA_WIDTH-1:0]      crc;
        logic [DATA_WIDTH-1:0]      decoded_tdata;
        logic [CTRL_WIDTH-1:0]      decoded_tkeep;
        axi_stream_t                axi_pkt;  
        crc_word_t                  axi_data_crc[$];  
        int                         data_cntr = 0;

        xgmii.delete();   

        while(state != COMPLETE) begin

            case(state)
                // Generate the header data (Preamble + SFD))
                HEADER: begin
                    data_shift_reg = {8'hD5, {6{8'h55}}, 8'hFB};
                    ctrl_shift_reg = 8'b00000001;
                    state = DATA;
                end
                DATA: begin
                    axi_pkt = axi_data.pop_back();

                    // Wehn recieveing the last work, if we have not recieved the minimum number of bytes (60 bytes)
                    // and tkeep != 4'b1111, we need to add padding. Therefore, we need to adjust the tkeep by changing
                    // any 0 bits to 1's
                    if (axi_pkt.axis_tlast && axi_pkt.axis_tkeep != 4'hF && data_cntr < 14)
                        decoded_tkeep = 4'hF;
                    else
                        decoded_tkeep = axi_pkt.axis_tkeep;

                    // Decode the input data based on the tkeep values - any byte that has an associated
                    // tkeep == 0, we set that byte to 0 in the decoded data
                    for(int i = 0; i < 4; i++) begin
                        if (axi_pkt.axis_tkeep[i])
                            decoded_tdata[i*8 +: 8] =  axi_pkt.axis_tdata[i*8 +: 8];
                        else
                            decoded_tdata[i*8 +: 8] =  8'h00;
                    end                        

                    data_shift_reg = {decoded_tdata, data_shift_reg[(2*DATA_WIDTH)-1 -: DATA_WIDTH]};
                    ctrl_shift_reg = {~decoded_tkeep, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: CTRL_WIDTH]};
                    axi_data_crc.push_front('{data_word: decoded_tdata, data_valid: decoded_tkeep});

                    if (axi_pkt.axis_tlast) begin
                        if (data_cntr < 14) begin
                            state = PADDING;
                        end else begin
                            state = CRC;
                        end
                    end

                    data_cntr++;

                end
                PADDING: begin
                    // Add padding to the data word as well as tot eh CRC calculation
                    data_shift_reg = {8'h00, data_shift_reg[(2*DATA_WIDTH)-1 -: DATA_WIDTH]};
                    ctrl_shift_reg = {4'h0, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: CTRL_WIDTH]}; 
                    axi_data_crc.push_front('{data_word: 8'h00, data_valid: 4'hF});

                    if (data_cntr >= 14) begin
                        state = CRC;
                    end

                    data_cntr++;        
       
                end
                CRC: begin
                    crc = crc32_slicing_by_4(axi_data_crc, lut);

                    case(~ctrl_shift_reg[(2*CTRL_WIDTH)-1:CTRL_WIDTH])
                        4'b0001: begin
                            data_shift_reg = {{2{8'h07}}, 8'hFD, crc, data_shift_reg[39 -: 8]};
                            ctrl_shift_reg = {3'b111, 1'b0, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: 4]};
                            state = IFG;
                        end
                        4'b0011: begin
                            data_shift_reg = {{1{8'h07}}, 8'hFD, crc, data_shift_reg[47 -: 16]};
                            ctrl_shift_reg = {2'b11, 2'b0, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: 4]};
                            state = IFG;
                        end
                        4'b0111: begin
                            data_shift_reg = {8'hFD, crc, data_shift_reg[55 -: 24]};
                            ctrl_shift_reg = {1'b1, 3'b0, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: 4]};
                            state = IFG;
                        end
                        4'b1111: begin
                            data_shift_reg = {crc, data_shift_reg[(2*DATA_WIDTH)-1 -: DATA_WIDTH]};
                            ctrl_shift_reg = {4'b0, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: 4]};
                            state = TERMINATE;
                        end
                    endcase                                       
                    
                end
                TERMINATE : begin
                    data_shift_reg = {{3{8'h07}}, 8'hFD, data_shift_reg[(2*DATA_WIDTH)-1 -: DATA_WIDTH]};
                    ctrl_shift_reg = {4'b1111, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: 4]};  
                    state = IFG;
                end
                IFG: begin
                    data_shift_reg = {{4{8'h07}}, data_shift_reg[(2*DATA_WIDTH)-1 -: DATA_WIDTH]};
                    ctrl_shift_reg = {4'b1111, ctrl_shift_reg[(2*CTRL_WIDTH)-1 -: 4]};

                    state = COMPLETE;
                end                
            endcase            

            xgmii.push_back('{xgmii_data: data_shift_reg[31:0], xgmii_ctrl: ctrl_shift_reg[3:0], xgmii_valid: 1'b1});
        end

    endfunction : tx_mac_ref_model

        class mac_coverage;

        typedef struct{
            int packets_over_60_bytes;
            int packets_under_60_bytes;
            int remainder_bytes_3;
            int remainder_bytes_2;
            int remainder_bytes_1;
            int remainder_bytes_0;
        } coverage_t;

        int coverage_complete;
        coverage_t cov_bins;


        function new();
            coverage_complete = 0;
            cov_bins = '{default:0};
        endfunction

        function void add_sample(int sample);
            
            // Sample whether we have packets over 60 bytes or under
            if (sample >= 60)
                cov_bins.packets_over_60_bytes++;
            else
                cov_bins.packets_under_60_bytes++;

            // Sample how many remaidner bytes were in the generated packet
            if (sample % 4 == 3)
                cov_bins.remainder_bytes_3++;
            else if (sample % 4 == 2)
                cov_bins.remainder_bytes_2++;
            else if (sample % 4 == 1)
                cov_bins.remainder_bytes_1++;
            else
                cov_bins.remainder_bytes_0++;

            // Update the coverage complete flag
            if ((cov_bins.packets_over_60_bytes > 10) &&
                (cov_bins.packets_under_60_bytes > 10) &&
                (cov_bins.remainder_bytes_3 > 5) &&
                (cov_bins.remainder_bytes_2 > 5) &&
                (cov_bins.remainder_bytes_1 > 5) &&
                (cov_bins.remainder_bytes_0 > 5))
                coverage_complete = 1;

        endfunction : add_sample

    endclass : mac_coverage

endpackage : mac_pkg