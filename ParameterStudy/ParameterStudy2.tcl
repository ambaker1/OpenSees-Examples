# Dynamic task assignment with OpenSeesMP/OpenSeesMPI
# Written by Alex Baker, 2021
if {[getNP] == 1} {
    puts "Must run in parallel"
    exit
}
if {[getPID] == 0} {
    set startT [clock seconds]
    # Dynamically assign tasks
    foreach at2File [glob -directory GM *.AT2] {
        foreach scaleFactor {0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0} {
            recv -pid ANY pid
            send -pid $pid [list $at2File $scaleFactor]
        }
    }
    # Send closing signal
    for {set i 1} {$i < [getNP]} {incr i} {
        recv -pid ANY pid
        send -pid $pid DONE
    }
    set endT [clock seconds]
    puts "Total analysis duration: [expr {$endT - $startT}] seconds"
    
    # Post-process results
    source PostProcess.tcl
} else {
    # Worker loop
    source ReadRecord.tcl
    while {1} {
        send -pid 0 [getPID]
        recv -pid 0 data
        if {$data eq "DONE"} {
            break
        } else {
            lassign $data at2File scaleFactor
            puts "Running $at2File at $scaleFactor scale..."
            source Cantilever.tcl
            wipe
        }
    }
}