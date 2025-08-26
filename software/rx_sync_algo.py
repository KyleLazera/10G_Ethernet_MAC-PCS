'''
This is intended to be a proof of concept for the rx block sync algorithm
implemented within the rx-data path of the 10G PCS. It is intended to mathematically
model the algorithm and ensure that my idea would work sufficiently. To see more about
how this algorithm was developed & its derivation, see the README.md.
'''

BLOCK_SIZE = 66
DATA_WIDTH = 32
MAX_NUM_BLOCKS = 500

def rx_sync_algorithm(num_junk_bits: int) -> int:
    '''
    This function contains the mathematical formula and implementation 
    used for the proof of concept of the rx block sync.

    argument(s): 
    num_junk_bits - Used to specify how many bits precede the first actual 
                    synchronous header.

    Return:
    int - The nummber of cycles required to re-align the synchronous header 
    '''
    expected_hdr_idx_list = []
    slip_cntr: int = 0

    # Generate the positions of the headers
    expected_hdr_idx_list = [num_junk_bits + BLOCK_SIZE * i for i in range(MAX_NUM_BLOCKS)]

    for hdr_idx, hdr_value in enumerate(expected_hdr_idx_list):
        # Increment slip counter on every odd cycle (simulate i_slip every 2nd cycle)
        if hdr_idx % 2 == 1:
            slip_cntr += 1

        # Calculate adjusted header position after slips
        adjusted_hdr_idx = hdr_value - (DATA_WIDTH) * slip_cntr

        # Check parity-aware alignment
        if (slip_cntr % 2 == 0 and adjusted_hdr_idx % BLOCK_SIZE in [0, 1]) or (slip_cntr % 2 == 1 and adjusted_hdr_idx % BLOCK_SIZE in [1, 2]):
            return slip_cntr
        
    return -1

def main() -> None:

    # We can have a total of 64 junk bits in 1 66 bit block (2 required for header)
    for i in range(65):
        slip_counts = rx_sync_algorithm(i)
        if slip_counts != -1:
            print(f"For Junk Bits: {i}, we require {slip_counts} slip(s)")
        else:
            print(f"Failed to find a valid slip count for {i}")


if __name__ == "__main__":
    main()
