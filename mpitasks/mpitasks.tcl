# mpitasks.tcl
################################################################################
# Load sharing task delegation with OpenSeesMP commands.

# Copyright (c) 2021 Alex Baker, ambaker1@mtu.edu

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################

# Define namespace
namespace eval ::mpitasks {
    # Internal variables
    variable inScope 0; # Variable to control access to "sendTask" command
    variable resultList ""; # List of results from tasks
    variable statusList ""; # List of task statuses (0 for done, 1 for running)
    variable workerList ""; # List of workers assigned to tasks
    variable commandPrefix ""; # Task command prefix
    
    # OpenSeesMP load sharing
    namespace export delegateTasks; # Efficient delegation of parallel tasks
    namespace export sendTask; # Send task (returns taskID)
    namespace export recvResults; # Get results from a task or all (may wait)
}

# delegateTasks --
#
# Command that works with OpenSeesMP MPI commands for efficient delegation of 
# parallel tasks. Returns list of results from all tasks.
#
# Arguments:
# commandPrefix:    Command prefix for task
# coordinatorBody:  Body to be evaluated by PID 0

proc ::mpitasks::delegateTasks {commandPrefix coordinatorBody} {
    variable inScope
    variable resultList ""
    variable statusList ""
    variable workerList ""
    variable workerCommand $commandPrefix
    
    # Get rank and number of processes
    set pid [getPID]
    set np [getNP]
    if {$np > 1} {
        barrier; # Ensure that all processes are accounted for.
    }
    # Switch for coordinator/worker
    if {$pid == 0} {
        # Initialize task ID and set inScope to true to enable task command.
        set inScope 1
        # Coordinator (worker as well if in series)
        set code [catch {uplevel 1 $coordinatorBody} result options]
        if {$np > 1} {
            # Send messages to close
            for {set i 1} {$i < $np} {incr i} {
                send -pid [GetWorker] CLOSE
            }
            # Send broadcasts of all task information
            send $resultList
            send $statusList
            send $workerList
        }
        # Reset inScope
        set inScope 0
        # Pass any caught error to caller
        if {$code != 0} {
            return -options $options
        }
    } else {
        # Worker
        send -pid 0 $pid; # Initial send
        while {1} {
            # Get instructions from coordinator
            recv -pid 0 message 
            lassign $message command taskID taskArgs
            switch $command {
                TASK {
                    # Perform task and send results to coordinator
                    set result [uplevel 1 $workerCommand $taskArgs]
                    send -pid 0 [list $pid $taskID $result]
                }
                RESET {
                    # Used when getting results prematurely
                    send -pid 0 $pid
                }
                CLOSE {
                    break
                }
                default {
                    return -code error "Unknown message from coordinator"
                }
            }
        }
        # Receive broadcasts of all task information
        recv resultList
        recv statusList
        recv workerList
    }
    return $resultList
}

# sendTask --
# 
# Sends a task to an available worker.
#
# Arguments:
# args:         Input arguments to worker command.

proc ::mpitasks::sendTask {args} {
    variable inScope
    variable resultList
    variable statusList
    variable workerList
    variable workerCommand
    if {!$inScope} {
        return -code error "\"sendTask\" called out of scope"
    }
    # Get next task ID
    set taskID [llength $resultList]
    # Send the job to an available worker
    if {[getNP] == 1} {
        set result [uplevel 1 $workerCommand $args]
        lappend resultList $result
        lappend statusList 0
        lappend workerList 0
    } else {
        set pid [GetWorker]
        send -pid $pid [list TASK $taskID $args]
        # Preliminary results
        lappend resultList ""
        lappend statusList 1
        lappend workerList $pid
    }
    return $taskID
}

# GetWorker --
# 
# Private procedure to get any worker and receive results if sent.

proc ::mpitasks::GetWorker {} {
    variable resultList
    variable statusList
    recv -pid ANY message 
    if {[llength $message] == 1} {
        set pid [lindex $message 0]
    } elseif {[llength $message] == 3} {
        # Save results
        lassign $message pid taskID result
        lset resultList $taskID $result
        lset statusList $taskID 0
    } else {
        return -code error "Unknown message from worker"
    }
    return $pid
}

# recvResults --
# 
# Get results from a specific task or all tasks. 
# Waits for workers if tasks are not done.
#
# Arguments:
# taskID:

proc ::mpitasks::recvResults {{taskID ""}} {
    variable resultList
    variable statusList
    variable workerList
    # Return list of results
    if {$taskID eq ""} {
        set taskID 0
        foreach status $statusList {
            if {$status == 1} {
                recvResults $taskID
            }
            incr taskID 
        }
        return $resultList
    }
    # Return individual result
    if {$taskID < 0 || $taskID >= [llength $resultList]} {
        return -code error "Invalid task ID"
    }
    # Handle active task (get results prematurely and reset worker)
    if {[getNP] != 1 && [lindex $statusList $taskID] == 1} {
        set pid [lindex $workerList $taskID]
        recv -pid $pid message
        if {[lindex $message 0] != $pid || [lindex $message 1] != $taskID} {
            return -code error "Unknown message from worker"
        }
        set result [lindex $message 2]
        lset resultList $taskID $result
        lset statusList $taskID 0
        send -pid $pid RESET
    }
    return [lindex $resultList $taskID]
}

# Import all exported commands to global
namespace import ::mpitasks::*
