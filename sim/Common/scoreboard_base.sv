
class scoreboard_base;

    /* Variables */
    int unsigned num_successes = 0;
    int unsigned num_failures = 0;

    /* Constructor */
    function new();
        num_successes = 0;
        num_failures = 0;
    endfunction

    /* Function to record success */
    virtual function void record_success();
        num_successes++;
    endfunction

    /* Function to record failure */
    virtual function void record_failure();
        num_failures++;
    endfunction

    /* Output scoreboard results */
    virtual function void print_summary();
        int unsigned total = num_successes + num_failures;
        $display("----- Scoreboard Summary -----");
        $display("Total Tests Run : %0d", total);
        $display("Successes       : %0d", num_successes);
        $display("Failures        : %0d", num_failures);
        $display("------------------------------");
    endfunction

endclass : scoreboard_base