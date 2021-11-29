# Cantilever column
# Written by Alex Baker, 2021
# Units are kips and inches
# Requires variables "at2File" and "scaleFactor".

# Define model dimensions
model BasicBuilder -ndm 2

# Steel material
set matTag 1; # integer material tag
set Fy 50.0; # yield stress, ksi
set E 29000.0; # elastic modulus, ksi
set b 0.02; # strain hardening ratio
uniaxialMaterial Steel01 $matTag $Fy $E $b

# Fiber section: W14X90
set secTag 1; # integer section tag
set d 14.0; # depth, in
set tw 0.440; # web thickness, in
set bf 14.5; # flange width, in
set tf 0.710; # flange thickness, in
set nfw 10; # number of fibers in web
set nff 10; # number of fibers in flange
section WFSection2d $secTag $matTag $d $tw $bf $tf 10 10

# Fiber section integration
set nPoints 5; # Number of integration points
set integration [list Lobatto $secTag $nPoints]

# Cantilever column geometry
set H 156.0; # height, in
node 1 0.0 0.0
node 2 0.0 $H
fix 1 1 1 1
geomTransf PDelta 1; # geometric transformation
element forceBeamColumn 1 1 2 1 $integration

# Gravity and mass
set P 500.0; # load, kips
set g 386.09; # gravity, in/sec^2
mass 2 [expr {$P/$g}] 0.0 0.0
timeSeries Linear 1
pattern Plain 1 1 {
    load 2 0.0 -$P 0.0
}

# Static analysis settings
wipeAnalysis
constraints Plain
numberer RCM
system BandSPD
test EnergyIncr 1.0e-6 10
algorithm Newton
integrator LoadControl 0.1
analysis Static

# Apply gravity and hold loads constant
analyze 10
loadConst
setTime 0.0

# Damping (stiffness proportional to first mode)
set lambda [eigen -fullGenLapack 1]
set pi [expr {2*asin(1.0)}]
set T1 [expr {2*$pi/sqrt($lambda)}]; # first mode period
set dr 0.05; # damping ratio
set alphaM 0.0; # mass matrix coefficient
set betaK [expr {$dr*$T1/$pi}]; # stiffness matrix coefficient
rayleigh $alphaM 0.0 $betaK 0.0; # initial stiffness proportional damping

# Pre-process and apply ground motion
set gmName [file rootname [file tail $at2File]]
set datFile "temp_[getPID].dat"; # temporary file for processor
ReadRecord $at2File $datFile dt npts
timeSeries Path 2 -dt $dt -filePath $datFile -factor [expr {$scaleFactor*$g}]
pattern UniformExcitation 2 1 -accel 2

# Dynamic analysis settings
wipeAnalysis
constraints Plain
numberer RCM
system BandSPD
test EnergyIncr 1.0e-6 100
algorithm Newton
integrator Newmark 0.5 0.25
analysis Transient

# Define procedure for convergence control (recursive bisection)
proc analyzeStep {dt {epsilon 1e-6}} {
    set ok [analyze 1 $dt]
    if {$ok != 0} {
        # Bisect and recurse (if possible)
        set dt [expr {$dt/2.0}]
        if {$dt > $epsilon} {
            set ok [analyzeStep $dt $epsilon]
            if {$ok == 0} {
                set ok [analyzeStep $dt $epsilon]
            }
        }
    }
    return $ok
}

# Define envelope recorders
set dataDir [file join Data $gmName $scaleFactor]
file mkdir $dataDir
recorder EnvelopeNode -file "$dataDir/NodeDispEnvelope.out" -node 2 -dof 1 disp
recorder EnvelopeNode -file "$dataDir/BaseShearEnvelope.out" -node 1 -dof 1 reaction

# Run analysis with convergence control
set duration [expr {$dt*$npts}]
while {[getTime] < $duration} {
    set ok [analyzeStep [expr {$dt/10.0}]]
    if {$ok != 0} {
        puts "Cantilever column failed" 
        break
    }
}

# Write analysis code to file
set fid [open "$dataDir/AnalysisCode.out" w]
puts $fid $ok
close $fid
