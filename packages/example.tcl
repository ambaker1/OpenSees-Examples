# Various Tcllib package examples
# Written by Alex Baker, 2022

# Math libraries
################################################################################
puts "MATH"

# Linear algebra
package require math::linearalgebra
namespace import math::linearalgebra::*
set A {{1 2} {3 4} {5 6}}
puts [transpose $A]
puts [getcol $A 0]

# Data structures
################################################################################
puts "\nSTRUCT"
package require struct::list

# Functional programming
puts [struct::list map {1 2 3 4} {format %.6f}]

# File utilities and JSON parsing (useful for JSON print output)
################################################################################
puts "\nJSON AND FILEUTIL"
package require json
package require fileutil

# Create simple model
model BasicBuilder -ndm 2
node 1 0 0
node 2 1 0
fix 1 1 1 1
fix 2 0 1 1
uniaxialMaterial Elastic 1 1000.0
element truss 1 1 2 10.0 1
print -JSON modelData.json

# Parse the JSON output
set modelData [json::json2dict [fileutil::cat modelData.json]]
puts "nodeTag\t\coords"
foreach nodeData [dict get $modelData StructuralAnalysisModel geometry nodes] {
    puts "[dict get $nodeData name]:\t[dict get $nodeData crd]"
}
