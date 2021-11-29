# Modulo task assignment with OpenSeesMP/OpenSeesMPI
# Written by Alex Baker, 2021
if {[getPID] == 0} {
    set startT [clock seconds]
}
source ReadRecord.tcl
set count 0
foreach at2File [glob -directory GM *.AT2] {
    foreach scaleFactor {0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0} {
        if {$count % [getNP] == [getPID]} {
            puts "Running $at2File at $scaleFactor scale..."
            source Cantilever.tcl
            wipe
        }
        incr count
    }
}
if {[getNP] > 0} {
    barrier
}
if {[getPID] == 0} {
    set endT [clock seconds]
    puts "Total analysis duration: [expr {$endT - $startT}] seconds"
    source PostProcess.tcl
}