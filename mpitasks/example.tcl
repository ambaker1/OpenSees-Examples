# Simple example use of mpitasks procedures
# Written by Alex Baker, 2021
source mpitasks.tcl

# Define task procedure (on all processes)
proc add {a b} {
    after 1000; # simulate long process (1 second)
    return [expr {$a + $b}]
}
# Delegate to processes using load-sharing scheme
delegateTasks add {
    # This body of code only executes on PID 0
    for {set a 1} {$a <= 5} {incr a} {
        for {set b 1} {$b <= 5} {incr b} {
            set taskID [sendTask $a $b]; # Returns index of task
        }
        recvResults; # waits for intermediate results
    }
}
# Get results (on all processes)
puts [recvResults]
