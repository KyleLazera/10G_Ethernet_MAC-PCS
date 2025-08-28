
class circular_buffer
#(  parameter BUFFER_SIZE = 66, 
    parameter BUFF_DATA_WIDTH = 32
);

    logic [BUFF_DATA_WIDTH-1:0] circ_buff [BUFFER_SIZE-1:0];
    int buff_ptr;

    //---------------------------------------------------------------
    // Constructor used to set the buffer pointer to 0, where it would
    // start writing data.
    //---------------------------------------------------------------
    function new();
        buff_ptr = 0;
    endfunction : new

    //---------------------------------------------------------------
    // Write data into the circular buffer, this function handles wrap
    // around logic & buffer pointer calculation
    //---------------------------------------------------------------
    function void write(logic [BUFF_DATA_WIDTH-1:0] data, bit i_slip);
        
        for(int i = 0; i < BUFF_DATA_WIDTH; i++) begin
            circ_buff[(buff_ptr + i) % BUFFER_SIZE] = data[i];
        end

        // Calculate the next write pointer location
        if (!i_slip)
            buff_ptr = (buff_ptr + BUFF_DATA_WIDTH) % BUFFER_SIZE;
    endfunction : write

    //---------------------------------------------------------------
    // Read and remove a 32 bit word from the circular buffer starting
    // from the specified index & for the specified length. This function
    // handles wrap around logic.
    //---------------------------------------------------------------
    function logic [BUFF_DATA_WIDTH-1:0] read(int start_index, int length);
        logic [BUFF_DATA_WIDTH-1:0] data = '0;
        
        for(int i = 0; i < length; i++) begin
            data[i] = circ_buff[(start_index + i) % BUFFER_SIZE];
        end

        return data;
    endfunction : read

    //---------------------------------------------------------------
    // Read the entire contents of the circular buffer and return it as
    // a single logic vector.
    //---------------------------------------------------------------
    function logic [BUFFER_SIZE-1:0] read_full_buffer();
        logic [BUFFER_SIZE-1:0] data;
        
        for(int i = 0; i < BUFFER_SIZE; i++) begin
            data[i] = circ_buff[i];
        end

        return data;
    endfunction : read_full_buffer

    function void peek();
        $display("Buffer Contents: %h", read_full_buffer());
        $display("Buffer Pointer: %0d", buff_ptr);
    endfunction : peek

    function int get_ptr();
        return buff_ptr;
    endfunction : get_ptr


endclass : circular_buffer