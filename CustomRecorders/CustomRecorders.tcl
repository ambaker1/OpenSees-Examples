# CustomRecorders.tcl
################################################################################
# Custom OpenSees recorders, implemented in Tcl

# Copyright 2021, Alex Baker (ambaker1@mtu.edu)

# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the "Software"), to deal 
# in the Software without restriction, including without limitation the rights 
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
# SOFTWARE.
################################################################################

# Return if already sourced.
if {[namespace exists ::CustomRecorders]} {
    return
}

# Define namespace
namespace eval ::CustomRecorders {
    # Internal variables
    variable crData ""; # Dictionary of custom recorder data
    variable crTag 0; # Initial custom recorder tag 
    
    # Traced commands
    # Traced OpenSees commands are not modified, but are traced so that
    # the custom recorders are affected when they are called.
    trace add execution ::record leave ::CustomRecorders::CustomRecord
    trace add execution ::wipe leave ::CustomRecorders::CloseCustomRecorders
    
    # Wrapped/Exported commands
    # Wrapped OpenSees commands are renamed, saved as "Real_*" in the
    # CustomRecorder namespace. Then, the equivalent commands are exported. 
    foreach command {analyze remove recorder recorderValue} {
        rename ::$command ::CustomRecorders::Real_$command
        namespace export $command
    }
}

# analyze --
# 
# Wrapped analyze command to update custom recorders after each successful step.

proc ::CustomRecorders::analyze {numIncr args} {
    # Loop through number of analysis steps.
    for {set i 0} {$i < $numIncr} {incr i} {
        set ok [Real_analyze 1 {*}$args]
        if {$ok == 0} {
            CustomRecord
        } else {
            break
        }
    }
    # Return the analysis code to user.
    return $ok
}

# recorder --
#
# Wrapped OpenSees recorder command to include custom recorder classes
# Returns a unique recorder tag (custom recorder tags are < 0, normal are >= 0)
#
# Arguments:
# type:         Recorder type (wrapped to include Custom and EnvelopeCustom)
# args:         Additional recorder arguments

proc ::CustomRecorders::recorder {type args} {
    switch $type {
        Custom {
            CustomRecorder {*}$args
        }
        EnvelopeCustom {
            EnvelopeCustomRecorder {*}$args
        }
        default {
            Real_recorder $type {*}$args
        }
    }
}

# recorderValue --
#
# Wrapped OpenSees recorderValue command to include Custom recorder class

proc ::CustomRecorders::recorderValue {recorderTag clmnID {rowOffset 0} args} {
    # Addition of custom recorder option
    if {$recorderTag < 0} {
        # Custom recorder
        variable crData
        if {[dict exists $crData $recorderTag]} {
            set data [dict get $crData $recorderTag data]
        } else {
            return -code error "Custom recorder $recorderTag does not exist"
        }
        if {[dict get $crData $recorderTag envelope]} {
            if {[lindex $args 0] eq "-reset"} {
                # Reset envelope for future steps
                dict set crData $recorderTag start 1
            }
            set value [lindex $data 2-$rowOffset $clmnID-1]
        } else {
            # Return the current value in the column.
            set value [lindex $data $clmnID-1]
        }
        # Return formatted value
        return [format [dict get $crData $recorderTag format] $value]
    } else {
        # Normal recorder
        Real_recorderValue $recorderTag $clmnID $rowOffset {*}$args
    }; # end if recorderTag
}

# remove --
#
# Wrapped OpenSees remove command to include Custom recorders

proc ::CustomRecorders::remove {type args} {
    switch $type {
        recorder {
            set recorderTag [lindex $args 0]
            if {$recorderTag < 0} {
                CloseCustomRecorder $recorderTag
                return; # do not call real remove
            }
        }
        recorders {
            CloseCustomRecorders
        }
    }
    # Call remove as usual
    Real_remove $type {*}$args
    # Return nothing
    return
}

# CustomRecorder (recorder Custom) --
#
# Custom recorder class. Allows for definition of script for a recorder.
# 
# Arguments:
# -file $filename:      Filename option (required)
# -fileAdd $filename:   Filename option (appends the file)
# -time:                Include "time" as first column
# -precision $nSD:      Set number of significant digits for output (default 6)
# -format $fmt:         Format for each value. Default %.${precision}g
# body:                 Body of custom recorder (evaluated like a proc)

proc ::CustomRecorders::CustomRecorder {args} {
    # Create a custom recorder
    variable crTag
    variable crData
    
    # Trim body from arguments
    set body [lindex $args end]
    set args [lrange $args 0 end-1]
    
    # Define defaults
    set precision 6
    set includeTime 0
    
    # Interpret args
    set i 0
    while {$i < [llength $args]} {
        switch [lindex $args $i] {
            -file {
                set filename [lindex $args $i+1]
                set access w
                incr i 2
            }
            -fileAdd {
                set filename [lindex $args $i+1]
                set access a
                incr i 2
            }
            -precision {
                set precision [lindex $args $i+1]
                if {![string is integer $precision]} {
                    return -code error "Precision must be integer"
                }
                incr i 2
            }
            -format {
                set format [lindex $args $i+1]
                incr i 2
            }
            -time {
                set includeTime 1
                incr i
            }
            default {
                return -code error "Incorrect input"
            }
        }; # end switch arg
    }; # end while i < nArgs
    if {![info exists filename]} {
        return -code error "Filename is required for custom recorder"
    }
    if {![info exists format]} {
        set format %.${precision}g; # Default format is based on precision
    }

    # Open file with specified access type
    if {[catch {set fid [open $filename $access]}]} {
        return -code error "Cannot open file \"$filename\" for writing"
    }
    
    # Open recorder file and save data.
    incr crTag -1; # Update custom recorder tag
    dict set crData $crTag fid $fid
    dict set crData $crTag body $body
    dict set crData $crTag includeTime $includeTime
    dict set crData $crTag data ""
    dict set crData $crTag format $format
    dict set crData $crTag envelope 0
    dict set crData $crTag start 1
    
    # Return custom recorder tag
    return $crTag
}

# EnvelopeCustomRecorder (recorder EnvelopeCustom)
#
# Records the min, max and absolute max of responses defined by custom script.
# 
# Arguments:
# -file $filename:      Filename option (required)
# -time:                Include "time"
# -precision $nSD:      Set number of significant digits for output (default 6)
# -format $fmt:         Format for each value. Default %.${precision}g
# body:                 Body of custom recorder (evaluated like a proc)

proc ::CustomRecorders::EnvelopeCustomRecorder {args} {
    # Create a custom recorder
    variable crTag
    variable crData
    CustomRecorder {*}$args
    # Make it an envelope recorder
    dict set crData $crTag envelope 1
    return $crTag
}

# CustomRecord --
# 
# Private proc to update custom recorders. 
# Called within analyze and used as a tracer on record.

proc ::CustomRecorders::CustomRecord {args} {
    # Run through all custom recorders, puts to file and update values.
    variable crData
    dict for {recorderTag subDict} $crData {
        # Evaluate script in global, and get values specified from script.
        # Can use "return" like in a procedure or a sourced file.
        set code [catch {uplevel "\#0" [dict get $subDict body]} result error]
        if {$code == 0 || $code == 2} {
            set values $result
        } elseif {$code == 1} {
            return -code error \
                    "Error in custom recorder: [dict get $error -errorinfo]"
        } else {
            return -code error "Exceptional return code in custom recorder"
        }
        
        # Switch for regular/envelope case
        if {[dict get $subDict envelope]} {
            # Switch for initialization case
            if {[dict get $subDict start]} {
                # Initialize data
                if {[dict get $subDict includeTime]} {
                    set time [getTime]
                    set data ""
                    foreach value $values {
                        lappend data $time $value
                    }
                    set data [list $data $data $data]
                } else {
                    set data [list $values $values $values]
                }
                dict set crData $recorderTag start 0
                set modified 1; # Initialize file
            } else {
                # Check new values against recorded peaks
                set data [dict get $subDict data]; # min, max, absmax
                set modified 0; # By default, don't modify file
                set min [lindex $data 0]
                set max [lindex $data 1]
                set absmax [lindex $data 2]
                # Switch for time option
                if {[dict get $subDict includeTime]} {
                    # Get time value
                    set time [getTime]
                    # Check maximum values
                    set newMax ""
                    foreach {maxTime maxValue} $max value $values {
                        if {$value > $maxValue} {
                            set modified 1
                            set maxTime $time
                            set maxValue $value
                        }
                        lappend newMax $maxTime $maxValue
                    }
                    set max $newMax
                    # Check minimum values
                    set newMin ""
                    foreach {minTime minValue} $min value $values {
                        if {$value < $minValue} {
                            set modified 1
                            set minTime $time
                            set minValue $value
                        }
                        lappend newMin $minTime $minValue
                    }
                    set min $newMin
                    # Check absolute maximum values (only if modified)
                    if {$modified} {
                        set newAbsmax ""
                        foreach {absmaxTime absmaxValue} $absmax value $values {
                            set absValue [expr {abs($value)}]
                            if {$absValue > $absmaxValue} {
                                set absmaxTime $time
                                set absmaxValue $absValue
                            }
                            lappend newAbsmax $absmaxTime $absmaxValue
                        }
                        set absmax $newAbsmax
                        set data [list $min $max $absmax]
                    }; # end if modified
                } else {
                    # Check maximum values
                    set newMax ""
                    foreach maxValue $max value $values {
                        if {$value > $maxValue} {
                            set modified 1
                            set maxValue $value
                        }
                        lappend newMax $maxValue
                    }
                    set max $newMax
                    # Check minimum values
                    set newMin ""
                    foreach minValue $min value $values {
                        if {$value < $minValue} {
                            set modified 1
                            set minValue $value
                        }
                        lappend newMin $minValue
                    }
                    set min $newMin
                    # Check absolute maximum values (only if modified)
                    if {$modified} {
                        set newAbsmax ""
                        foreach absmaxValue $absmax value $values {
                            set absValue [expr {abs($value)}]
                            if {$absValue > $absmaxValue} {
                                set absmaxValue $absValue
                            }
                            lappend newAbsmax $absmaxValue
                        }
                        set absmax $newAbsmax
                        set data [list $min $max $absmax]
                    }; # end if modified
                }; # end if time option
            }; # end if initializing envelope
            # Only update if modified
            if {$modified} {
                dict set crData $recorderTag data $data; # Save data
                # Truncate envelope file
                set fid [dict get $subDict fid]
                chan truncate $fid 0
                seek $fid 0 start
                # Write to file with specified format
                set format [dict get $subDict format]
                foreach line $data {
                    puts $fid [lmap value $line {format $format $value}]
                }
            }; # end if modified (write to file)
        } else {
            # Switch for time option
            if {[dict get $subDict includeTime]} {
                set data [concat [getTime] $values]
            } else {
                set data $values
            }; # end if include time
            dict set crData $recorderTag data $data; # Save value
            # Write to file with specified format
            set format [dict get $subDict format]
            puts [dict get $subDict fid] [lmap value $data {
                format $format $value
            }]
        }; # end if envelope
    }; # end dict for custom recorders
    
    return
}

# CloseCustomRecorder --
#
# Private proc to close a specific custom recorder. 
# Called within remove recorder if recorder tag is negative.

proc ::CustomRecorders::CloseCustomRecorder {recorderTag} {
    variable crData
    # Custom recorder
    if {[dict exists $crData $recorderTag]} {
        # Close file and unset entry in dictionary
        close [dict get $crData $recorderTag fid]
        dict unset crData $recorderTag
    } else {
        return -code error "Custom recorder $recorderTag does not exist"
    }
    # Return nothing
    return
}

# CloseCustomRecorders --
#
# Private proc to close all custom recorders. 
# Called within remove recorders and wipe.

proc ::CustomRecorders::CloseCustomRecorders {args} {
    variable crData
    # Close all file-IDs in custom recorder dictionary.
    dict for {recorderTag subDict} $crData {
        close [dict get $subDict fid]
    }
    # Over-write custom recorder dictionary
    set crData ""
    # Return nothing
    return
}

# Import all wrapped commands
namespace import ::CustomRecorders::*
