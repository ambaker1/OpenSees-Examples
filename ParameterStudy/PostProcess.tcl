# Post-process results for matlab script
# Written by Alex Baker, 2021
set results [open results.csv w]; # file ID for writing results
puts $results "gm,factor,disp,shear,code"
cd Data
foreach gmName [glob -type d *] {
    cd $gmName
    foreach scaleFactor [glob -type d *] {
        cd $scaleFactor
        # Read files
        set fid [open NodeDispEnvelope.out r]
        set disp [lindex [read $fid] end]
        close $fid
        set fid [open BaseShearEnvelope.out r]
        set shear [lindex [read $fid] end]
        close $fid
        set fid [open AnalysisCode.out r]
        set code [lindex [read $fid] end]
        close $fid
        puts $results "$gmName,$scaleFactor,$disp,$shear,$code"
        cd ..
    }
    cd ..
}
cd ..
close $results
