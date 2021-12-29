# Demo of custom recorders - using "truss.tcl" as an example
source CustomRecorders.tcl

# OpenSees -- Open System for Earthquake Engineering Simulation
# Pacific Earthquake Engineering Research Center
# http://opensees.berkeley.edu/
#
# Basic Truss Example
# ----------------------
#  2d 3 Element Elastic Truss
#  Single Nodal Load, Static Analysis
# 
# Example Objectives
# -----------------
#  Simple Introduction to OpenSees
# 
# Units: kips, in, sec
# Written: fmk
# Date: January 2001

# ------------------------------
# Start of model generation
# ------------------------------

# Remove existing model
wipe

# Create ModelBuilder (with two-dimensions and 2 DOF/node)
model BasicBuilder -ndm 2 -ndf 2

# Create nodes
# ------------
    
# Create nodes & add to Domain - command: node nodeId xCrd yCrd
node 1   0.0  0.0
node 2 144.0  0.0
node 3 168.0  0.0
node 4  72.0 96.0

# Set the boundary conditions - command: fix nodeID xResrnt? yRestrnt?
fix 1 1 1 
fix 2 1 1
fix 3 1 1

# Define materials for truss elements
# -----------------------------------

# Create Elastic material prototype - command: uniaxialMaterial Elastic matID E
uniaxialMaterial Elastic 1 3000

# Define elements
# ---------------

# Create truss elements - command: element truss trussID node1 node2 A matID
element truss 1 1 4 10.0 1
element truss 2 2 4  5.0 1
element truss 3 3 4  5.0 1
    
# Define loads
# ------------

#create a Linear TimeSeries (load factor varies linearly with time): command timeSeries Linear $tag
timeSeries Linear 1

# Create a Plain load pattern with a linear TimeSeries: command pattern Plain $tag $timeSeriesTag { $loads }
pattern Plain 1 1 {
    
    # Create the nodal load - command: load nodeID xForce yForce
    load 4 100 -50
}
    
# ------------------------------
# Start of analysis generation (Modified for custom recorder example)
# ------------------------------
system BandSPD
numberer RCM
constraints Plain
integrator LoadControl 0.1
algorithm Newton
test NormUnbalance 1e-6 10
analysis Static 

# ------------------------------
# Start of recorder generation
# ------------------------------

# create a Recorder object for the nodal displacements at node 4
recorder Node -file example.out -time -precision 12 -node 4 -dof 1 2 disp


# Create a recorder for element forces, one in global and the other local system
recorder Element -file eleGlobal.out -time -ele 1 2 3 forces
recorder Element -file eleLocal.out -time -ele 1 2 3  basicForces

# Custom recorders
################################################################################
# Get basic files with steps and analysis time
set count 0
recorder Custom -file steps.out {incr count}
recorder Custom -file time.out {getTime}

# Get convergence info
recorder Custom -file test_stats.out {list [testIter] {*}[testNorms]}

# Use conditional expressions
recorder Custom -file even.out -format %s {
    if {$count % 2 == 0} {
        return yes
    } else {
        return no
    }
}

# Perform puts to screen and also write separate values to file.
set message "Hello World"
recorder Custom -file custom.out -time {
    if {[getTime] > 0.5} {
        puts $message
        return 1
    }
    incr i
}

# Envelope recorder 
set recTag1 [recorder EnvelopeNode -time -file envelope1.out -node 2 4 -dof 1 2 disp]
set recTag2 [recorder EnvelopeCustom -file envelope2.out -time {
    list [nodeDisp 2 1] [nodeDisp 2 2] [nodeDisp 4 1] [nodeDisp 4 2]
}]

record
# ------------------------------
# Finally perform the analysis
# ------------------------------

# Perform the analysis
analyze 10

# Print the current state at node 4 and at all elements 
puts "node 4 displacement: [nodeDisp 4]"
print node 4
print ele

puts "Comparison of \"recorderValue\""

# Get values from custom recorders
# Traditional envelope
puts [recorderValue $recTag1 6]
puts [recorderValue $recTag1 6 1]
puts [recorderValue $recTag1 6 2]
# Custom envelope (returns value, formatted as specified in custom recorder)
puts [recorderValue $recTag2 6]
puts [recorderValue $recTag2 6 1]
puts [recorderValue $recTag2 6 2]


