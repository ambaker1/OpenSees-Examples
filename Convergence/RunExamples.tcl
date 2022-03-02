# Run analyses
foreach factor {1.0 5.0 10.0} {
    source RCFrameEarthquake1.tcl
    wipe
    source RCFrameEarthquake2.tcl
    wipe
}