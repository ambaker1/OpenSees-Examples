# Example from OpenSees wiki:
# https://opensees.berkeley.edu/wiki/index.php/Reinforced_Concrete_Frame_Earthquake_Analysis
# Modified by Alex Baker, 2022
# Changes: 
#   Changed earthquake record for example
#   Added "factor" for scaling earthquake
#   Added "dataDir" for recorders
#   Fixed backwards compatibility with -Umfpack eigen solver.
#   Changed Tcl convergence algorithm

# Do operations of RCFrameGravity by sourcing in the tcl file
source RCFrameGravity.tcl

# Set the gravity loads to be constant & reset the time in the domain
loadConst -time 0.0

# Define nodal mass in terms of axial load on columns
set g 386.4
set m [expr $P/$g];       # expr command to evaluate an expression

#    tag   MX   MY   RZ
mass  3    $m   $m    0
mass  4    $m   $m    0

# Set some parameters
set record RSN953_NORTHR_MUL009
set factor 5.0
set dataDir data2/$factor
file mkdir $dataDir

# Source in TCL proc to read PEER SMD record
source ReadRecord.tcl

# Permform the conversion from SMD record to OpenSees record
#              inFile     outFile dt
ReadRecord $record.at2 $record.dat dt nPts

# Set time series to be passed to uniform excitation
timeSeries Path 1 -filePath $record.dat -dt $dt -factor $g

# Create UniformExcitation load pattern
#                         tag dir 
pattern UniformExcitation  2   1  -accel 1 -factor $factor

# set the rayleigh damping factors for nodes & elements
rayleigh 0.0 0.0 0.0 0.000625

# Create a recorder to monitor nodal displacements
recorder Node -time -file $dataDir/disp.out -node 3 4 -dof 1 2 3 disp

# Create recorders to monitor section forces and deformations
# at the base of the left column
recorder Element -time -file $dataDir/ele1secForce.out -ele 1 section 1 force
recorder Element -time -file $dataDir/ele1secDef.out   -ele 1 section 1 deformation

# Delete the old analysis and all it's component objects
wipeAnalysis

# Create the system of equation, a banded general storage scheme
system BandGeneral

# Create the constraint handler, a plain handler as homogeneous boundary
constraints Plain

# Create the convergence test, the norm of the residual with a tolerance of 
# 1e-12 and a max number of iterations of 10
test NormDispIncr 1.0e-12  10 

# Create the solution algorithm, a Newton-Raphson algorithm
algorithm Newton

# Create the DOF numberer, the reverse Cuthill-McKee algorithm
numberer RCM

# Create the integration scheme, the Newmark with alpha =0.5 and beta =.25
integrator Newmark  0.5  0.25 

# Create the analysis object
analysis Transient

# Perform an eigenvalue analysis
puts "eigen values at start of transient: [eigen 2]"

# Define procedure for convergence control (recursive bisection)
proc analyzeStep {dt {epsilon 1e-6}} {
    # Perform analysis step
    set ok [analyze 1 $dt]
    # Handle non-convergence
    if {$ok != 0} {
        # Base case
        if {$dt < 2*$epsilon} {
            return $ok
        }
        # Bisect analysis step and recurse
        set dt [expr {$dt/2.0}]
        set ok [analyzeStep $dt $epsilon]
        if {$ok == 0} {
            set ok [analyzeStep $dt $epsilon]
        }
    }
    return $ok
}

# Run analysis with convergence control
set tFinal [expr $nPts * $dt]
while {[getTime] < $tFinal} {
    set ok [analyzeStep $dt]
    if {$ok != 0} {
        break
    }
}

# Print a message to indicate if analysis succesfull or not
if {$ok == 0} {
   puts "Transient analysis completed SUCCESSFULLY";
} else {
   puts "Transient analysis completed FAILED";    
}

# Perform an eigenvalue analysis
system UmfPack
puts "eigen values at end of transient: [eigen 2]"

# Print state of node 3
print node 3
