
`include "../Encoder_Sim/xgmii_encoder_pkg.sv"
`include "../Gearbox_Sim/gearbox_pkg.sv"

package pcs_pkg;

    `include "pcs_scb.sv"

    import gearbox_pkg::*;
    import xgmii_encoder_pkg::*;

    /* Parameters */
    localparam ENCODED_BLOCK_WIDTH = 66;
    localparam OUTPUT_DATA_WIDTH = 32;

    /* Queue Declarations */
    logic pcs_ref_model[$];

    /* Class Declarations */
    pcs_scb scb = new();

    /*
     * Takes in an XGMII frame which is comprised of a 64-bit word along
     * with an 8 bit control word. This frame is then split into 32-bit 
     * data width, scrambled and passed through a gearbox model.
     */
    function void pcs_golden_model(xgmii_frame_t xgmii_frame);

        encoded_data_t encoded_data_32b, scrambled_data_32b;

        logic [ENCODED_BLOCK_WIDTH-1:0] encoded_data_66b;
        logic [57:0] lfsr_golden = {58{1'b1}};

        // 1) Encode the Data with 64b/66b encoding 
        encoded_data_66b = encode_data(xgmii_frame.data_word, xgmii_frame.ctrl_word);

        // Split the 66-bit word into synch header and 2, 32-bit words
        encoded_data_32b = split_66_bit_frame(encoded_data_66b);

        // 2) Scramble the data words (not the sync header)
        scrambled_data_32b.sync_hdr = encoded_data_32b.sync_hdr;
        foreach(scrambled_data_32b.data_word[i]) begin
            scrambled_data_32b.data_word[i] = scramble_golden_model(encoded_data_32b.data_word[i], lfsr_golden);
        end

        // 3) Store serial data in the gearbox model
        gearbox_ref_model(scrambled_data_32b, pcs_ref_model);

    endfunction : pcs_golden_model

    /*
     * Validate the real data with the expected data from the model queue.
     * This function also keeps track of the umber of successes/failsures using
     * teh pcs scoreboard.
     */
    function void validate_data(logic [OUTPUT_DATA_WIDTH-1:0] rx_data);

        logic [OUTPUT_DATA_WIDTH-1:0] ref_data;

        // get ref data for comparison
        ref_data = pack_bits_32b();

        // Verify data and store results in scoreboard
        scb.verify_data(ref_data, rx_data);

    endfunction : validate_data

    /* ---------------------------------- Helper Functions ---------------------------------- */

    /*
     * Helper function that takes in a 66 bit frame from the 64/66b
     * encoding module and splits it into 2, 32-bit frames along with 
     * a 2-bit synchronous header.
     */
    function encoded_data_t split_66_bit_frame(logic [ENCODED_BLOCK_WIDTH-1:0] encoded_frame);
        
        encoded_data_t encoded_data;
    
        encoded_data.sync_hdr = encoded_frame[65:64];
        encoded_data.data_word[1] = encoded_frame[63 -: 32];
        encoded_data.data_word[0] = encoded_frame[31:0];

        return encoded_data;

    endfunction : split_66_bit_frame

    /* Scrambler Golden Model */
    function automatic [31:0] scramble_golden_model (
        input  logic [31:0] data_in,
        inout  logic [57:0] lfsr
    );
        logic [31:0] data_out;
        logic feedback;
        int i;

        for (i = 0; i < 32; i++) begin
            // Scramble input bit using MSB of LFSR
            data_out[i] = data_in[i] ^ lfsr[57] ^ lfsr[38];

            // Shift LFSR and insert new feedback bit
            lfsr = {lfsr[56:0], data_out[i]};
        end

        return data_out;

    endfunction    

    /*
     * Store the scrambler data and header information in a queue that will be used
     * as a reference model. This queue simulates what the output stream should look
     * like for the PCS tx data path. 
     */
    function void gearbox_ref_model(encoded_data_t scrambler_data, ref logic pcs_model[$]);
        
        pcs_model.push_front(scrambler_data.sync_hdr[0]);
        pcs_model.push_front(scrambler_data.sync_hdr[1]);

        foreach(scrambler_data.data_word[i]) begin
            for(int j = 0; j < 32; j++)
                pcs_model.push_front(scrambler_data.data_word[i][j]);
            end
    endfunction : gearbox_ref_model

    /*
     * This function pulls the last 32 bits from the pcs_ref_model, and packs
     * them into a packed vector, allowing for simple comparison.
     */
    function automatic [OUTPUT_DATA_WIDTH-1:0] pack_bits_32b();
        logic [OUTPUT_DATA_WIDTH-1:0] rx_data, ref_data_packed;
        logic ref_data_unpacked [OUTPUT_DATA_WIDTH-1:0];

        // Remove 32 bits from the back of the reference model
        if (pcs_ref_model.size >= 32) begin
            for(int i = 0; i < 32; i++) begin
                ref_data_unpacked[i] = pcs_ref_model.pop_back();
            end

            // Pack the 32 bits into a vector for comparison
            ref_data_packed = {>>{ref_data_unpacked}};
            
            return ref_data_packed;
        end
    endfunction : pack_bits_32b


endpackage : pcs_pkg