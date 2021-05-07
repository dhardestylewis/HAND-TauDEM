## Workflow that returns height-above-nearest-drainage (HAND) from source data

## Author: Daniel Hardesty Lewis
## Copyright: Copyright 2020, Daniel Hardesty Lewis
## Credits: Daniel Hardesty Lewis
## License: GPLv3
## Version: 1.0.0
## Maintainer: Daniel Hardesty Lewis
## Email: dhl@tacc.utexas.edu
## Status: Production



## Import needed modules
import argparse
import subprocess
import pandas as pd
from pathlib import Path
from threading import Thread
from collections import deque
import time
import gc
import sys
from io import BytesIO
import getpass
import shlex


def argparser():
    ## Define input and output file locations

    parser = argparse.ArgumentParser()

    ## path of HAND-TauDEM sbatch script
    parser.add_argument(
        "-b",
        "--path_sbatch",
        type=str,
        help="path of HAND-TauDEM sbatch script"
    )
    ## number of jobs on each node
    parser.add_argument(
        "-j",
        "--jobs",
        type=int,
        help="number of jobs on each node"
    )
    ## path of the HAND-TauDEM Singularity image
    parser.add_argument(
        "-i",
        "--path_img",
        type=str,
        help="path of the HAND-TauDEM Singularity image"
    )
    ## path of the HAND-TauDEM bash script
    parser.add_argument(
        "-s",
        "--path_sh",
        type=str,
        help="path of the HAND-TauDEM bash script"
    )
    ## path of the HAND-TauDEM log file
    parser.add_argument(
        "-l",
        "--path_log",
        type=str,
        help="path of the HAND-TauDEM log file"
    )
    ## path of the HAND-TauDEM commands script
    parser.add_argument(
        "-c",
        "--path_cmds",
        type=str,
        help="path of the HAND-TauDEM commands script"
    )
    ## path of the HAND-TauDEM command outputs list
    parser.add_argument(
        "-o",
        "--path_cmd_outputs",
        type=str,
        help="path of the HAND-TauDEM command outputs list"
    )
    ## path of the HAND-TauDEM commands configuration file
    parser.add_argument(
        "-r",
        "--path_rc",
        type=str,
        help="path of the HAND-TauDEM commands configuration file"
    )
    ## minutes between scheduler checks
    parser.add_argument(
        "-m",
        "--minutes",
        type=int,
        help="minutes between scheduler checks"
    )
    ## Input DEMs to parse
    parser.add_argument(
        "pos",
        nargs='*',
        type=str,
        help="Input DEMs to parse"
    )

    args = parser.parse_args()

    ## Check that the required input files have been defined
    if not args.path_sbatch:
        parser.error('-b --path_sbatch HAND sbatch file not specified')
    if not args.jobs:
        parser.error('-j --jobs Input number of jobs per node not specified')
    if not args.path_img:
        parser.error('-i --path_img HAND Singularity image file needed')
    if not args.path_sh:
        parser.error('-s --path_sh HAND Bash script file not specified')
    if not args.path_log:
        parser.error('-l --path_log HAND log file not specified')
    if not args.path_cmds:
        parser.error('-c --path_cmds HAND Bash commands file not given')
    if not args.path_cmd_outputs:
        parser.error('-o --path_cmd_outputs Command outputs not given')
    if not args.path_rc:
        parser.error('-r --path_rc HAND configuration file not specified')
    if not args.pos:
        parser.error('Input DEMs not specified')

    return(args)


class TaskProcessor(Thread):
    """
    https://stackoverflow.com/a/53505397
    CC BY-SA 4.0 2018 Darkonaut
    Processor class which monitors memory usage for running tasks (processes).
    Suspends execution for tasks surpassing `max_b` and completes them one
    by one, after behaving tasks have finished.
    """

    #def _bashCmdQLim(self):
    #    self.bashCmd = "qlimits | \
    #                    sed -n '5,12p;13q' | \
    #                    grep ^" + self.queue + " | \
    #                    tr -s ' ' | \
    #                    cut -d ' ' -f4"

    def __init__(self, tasks):

        super().__init__()

        self.qlim_total = 50

        self.queue = 'development'
        output = '1'
#        self._bashCmdQLim()
#        process = subprocess.Popen(
#            self.bashCmd.split(),
#            stdout=subprocess.PIPE
#        )
#        output, error = process.communicate()
        self.qlim_dev = int(output)

        self.queue = 'normal'
        output = '50'
#        self._bashCmdQLim()
#        process = subprocess.Popen(
#            self.bashCmd.split(),
#            stdout=subprocess.PIPE
#        )
#        output, error = process.communicate()
        self.qlim_norm = int(output)

        self.queue = 'long'
        output = '2'
#        self._bashCmdQLim()
#        process = subprocess.Popen(
#            self.bashCmd.split(),
#            stdout=subprocess.PIPE
#        )
#        output, error = process.communicate()
        self.qlim_long = int(output)

        self.tasks = deque(tasks)

        self._running_tasks = []
        self._running_tasks_dev = []
        self._running_tasks_norm = []
        self._running_tasks_long = []

        self.user = getpass.getuser()

    def run(self):
        """Main-function in new thread."""
        self._update_running_tasks()
        self._monitor_running_tasks()

    def _bashCmdStr(self):
        """Structure sbatch command after evaluating current queue usage"""
        self.bashCmd = (
            "sbatch" +
                " -p "    + self.queue +
                " -t "    + self.hours + ":00:00" +
                " -N 1"   +
                " -n 48 " +
                args.path_sbatch +
                    " -j "                      + str(args.jobs) +
                    " --path_img "         + args.path_img +
                    " --path_sh "          + args.path_sh +
                    " --path_log "         + self.logfile.__str__() +
                    " --path_cmds "        + args.path_cmds +
                    " --path_cmd_outputs " + args.path_cmd_outputs +
                    " --path_rc "          + args.path_rc +
                    " --queue "                 + self.queue +
                    " --start_time "            + str(self.start_time) +
                " " + self.p
        )

    def _subprocess_Popen(self):
        """Query squeue for all running jobs for this user"""
        process = subprocess.Popen(
            shlex.split(self.bashCmd),
            stdout = subprocess.PIPE,
            stderr = subprocess.PIPE
        )
        self.output, self.error = process.communicate()

    def _squeue(self):
        """Query squeue for all running jobs for this user"""
        self.bashCmd = (
            "squeue" +
                " -u " + self.user +
                ' -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D"'
        )
        self._subprocess_Popen()
        if self.error == b'':
            squeue = pd.read_csv(BytesIO(self.output),sep="\s+")
            self._running_tasks_len = squeue.shape[0]
            self._running_tasks_dev_len = (
                squeue['PARTITION']=='development'
            ).sum()
            self._running_tasks_norm_len = (
                squeue['PARTITION']=='normal'
            ).sum()
            self._running_tasks_long_len = (
                squeue['PARTITION']=='long'
            ).sum()
        else:
            print(self.bashCmd)
            print(self.error)
            print('BREAK at line 211')
        #    break

    def _logcsv(self):
        """Query log for this task"""
        self.logcsv = pd.read_csv(
            self.logfile,
            index_col = 'index',
#            usecols = [
#                'pid',
#                'start_time',
#                'queue',
#                'elapsed_time',
#                'error_long_queue_timeout',
#                'complete',
#                'last_cmd'
#            ],
            dtype = {
                'pid' : int,
                'start_time' : int,
                'queue' : str,
                'elapsed_time' : int,
                'error_long_queue_timeout' : bool,
                'complete' : bool,
                'last_cmd' : str
            }
        )
        self.idx = self.logcsv.index[0]

    def _running_tasks_dict(self):
        """Construct info dict for this task"""
        self.running_tasks_dict = {
            self.job_id : {
                'queue' : self.queue,
                'dem' : self.p,
                'log' : self.logfile
            }
        }

    def _update_running_tasks(self):
        """Start new tasks if we have less running tasks than cores."""

        self._squeue()
        while (

            ## Stay under overall Stampede2 job limit
            len(self._running_tasks) < self.qlim_total and
            self._running_tasks_len < self.qlim_total and
            ( 
                ## Stay under specific Stampede2 queues' job limits
                len(self._running_tasks_dev) < self.qlim_dev or
                len(self._running_tasks_norm) < self.qlim_norm or
                len(self._running_tasks_long) < self.qlim_long
            ) and
            ( 
                ## Stay under specific Stampede2 queues' job limits
                self._running_tasks_dev_len < self.qlim_dev or
                self._running_tasks_norm_len < self.qlim_norm or
                self._running_tasks_long_len < self.qlim_long
            ) and
            len(self.tasks) > 0
        ):

            gc.collect()

            self.p = self.tasks.popleft()

            ## TODO Make specifying log file name optional
            #self.logfile = Path(self.p).parent.absolute().joinpath('hand-taudem.log')
            self.logfile = Path(self.p).parent.absolute().joinpath(args.path_log)
            if not self.logfile.is_file():
                self.logcsv = pd.DataFrame(
                    index = [int()],
                    data = {
                        'pid' : [int()],
                        'start_time' : [int()],
                        'queue' : ['development'],
                        'elapsed_time' : [args.minutes * 60 + 1],
                        'error_long_queue_timeout' : [False],
                        'complete' : [False],
                        'last_cmd' : ['touch'],
                        'exit_code' : [0]
                    }
                )
                self.logcsv.index.names = ['index']
                self.logcsv.to_csv(self.logfile)

            self._logcsv()

            if self.logcsv.loc[self.idx,'error_long_queue_timeout'] == False:

                if self.logcsv.loc[self.idx,'queue'] == 'long':
                    if (
                        self.logcsv.loc[self.idx,'elapsed_time'] > args.minutes * 60
                    ):
                        if (
                            len(self._running_tasks_long) < self.qlim_long and
                            self._running_tasks_long_len < self.qlim_long
                        ):
                            self.queue = 'long'
                            self.hours = '120'
                        else:
                            continue
                    else:
                        self.logcsv.loc[self.idx,'error_long_queue_timeout'] = True
                elif self.logcsv.loc[self.idx,'queue'] == 'normal':
                    if (
                        self.logcsv.loc[self.idx,'elapsed_time'] > args.minutes * 60
                    ):
                        if (
                            len(self._running_tasks_norm) < self.qlim_norm and
                            self._running_tasks_norm_len < self.qlim_norm
                        ):
                            self.queue = 'normal'
                            self.hours = '48'
                        elif (
                            len(self._running_tasks_long) < self.qlim_long and
                            self._running_tasks_long_len < self.qlim_long
                        ):
                            self.queue = 'long'
                            self.hours = '120'
                        else:
                            continue
                    else:
                        if (
                            len(self._running_tasks_long) < self.qlim_long and
                            self._running_tasks_long_len < self.qlim_long
                        ):
                            self.queue = 'long'
                            self.hours = '120'
                        else:
                            continue
                elif self.logcsv.loc[self.idx,'queue'] == 'development':
                    if (
                        self.logcsv.loc[self.idx,'elapsed_time'] > args.minutes * 60
                    ):
                        if (
                            len(self._running_tasks_dev) < self.qlim_dev and
                            self._running_tasks_dev_len < self.qlim_dev
                        ):
                            self.queue = 'development'
                            self.hours = '02'
                        elif (
                            len(self._running_tasks_norm) < self.qlim_norm and
                            self._running_tasks_norm_len < self.qlim_norm
                        ):
                            self.queue = 'normal'
                            self.hours = '48'
                        elif (
                            len(self._running_tasks_long) < self.qlim_long and
                            self._running_tasks_long_len < self.qlim_long
                        ):
                            self.queue = 'long'
                            self.hours = '120'
                        else:
                            continue
                    else:
                        if (
                            len(self._running_tasks_norm) < self.qlim_norm and
                            self._running_tasks_norm_len < self.qlim_norm
                        ):
                            self.queue = 'normal'
                            self.hours = '48'
                        elif (
                            len(self._running_tasks_long) < self.qlim_long and
                            self._running_tasks_long_len < self.qlim_long
                        ):
                            self.queue = 'long'
                            self.hours = '120'
                        else:
                            continue
                else:
                    print("self.logcsv.loc[self.idx,'queue']")
                    print(self.logcsv.loc[self.idx,'queue'])
                    print("self.logcsv.loc[self.idx,'queue'] BREAK at line 362")
                    break

            else:
                continue

            if self.logcsv.loc[self.idx,'error_long_queue_timeout'] == False:

                self.bashCmd = "date -u +%s"
                self._subprocess_Popen()
                if self.error == b'':
                    self.start_time = int(self.output.decode("utf-8"))
                else:
                    print('BREAK at line 375')
                    print(self.bashCmd)
                    print(self.error)
                    break

                self._bashCmdStr()
                self._subprocess_Popen()
                if (
                    self.error == b'' and
                    'FAILED' not in self.output.decode("utf-8")
                ):
                    self.job_id = int(self.output.split()[-1])
                else:
                    print('BREAK at line 389')
                    print(self.bashCmd)
                    print(self.output)
                    print(self.error)
                    break

                self._running_tasks_dict()
                if self.queue == 'long':
                    self._running_tasks_long.append(
                        self.running_tasks_dict
                    )
                elif self.queue == 'normal':
                    self._running_tasks_norm.append(
                        self.running_tasks_dict
                    )
                elif self.queue == 'development':
                    self._running_tasks_dev.append(
                        self.running_tasks_dict
                    )
                else:
                    print('self.queue')
                    print(self.queue)
                    print('self.queue BREAK at line 409')
                    break

                self._running_tasks.append(
                    self.running_tasks_dict
                )
                print(f'Started process: {self._running_tasks[-1]}')

            else:
                continue

            self._squeue()

    def _monitor_running_tasks(self):
        """
        Monitor running tasks. Replace completed tasks and suspend tasks
        which exceed the memory threshold `self.max_b`.
        """

        # loop while we have running or non-started tasks
        while self._running_tasks or self.tasks:
            # Without it, p.is_running() below on Unix would not return
            # `False` for finished processes.
            self._update_running_tasks()
            actual_tasks = self._running_tasks.copy()

            print("actual_tasks")
            print(actual_tasks)
            for p in actual_tasks:

                key = list(p.keys())[0]
                print("task")
                print(p)

                self.bashCmd = (
                    "squeue" +
                        " -j " + str(key) +
                        ' -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D"'
                )
                self._subprocess_Popen()
                print("self.output")
                print(self.output)
                print("self.error")
                print(self.error)
                #if list(p.keys())[0].poll() is not None:  ## process has finished
                if self.error != b'':  ## process has finished

                    print("key")
                    print(key)
                    
                    if p[key]['queue'] == 'long':
                        self._running_tasks_long.remove(p)
                    elif p[key]['queue'] == 'normal':
                        self._running_tasks_norm.remove(p)
                    elif p[key]['queue'] == 'development':
                        self._running_tasks_dev.remove(p)
                    else:
                        print("p[key]['queue']")
                        print(p[key]['queue'])
                        print("p[key]['queue'] CONTINUE at line 477")
                        continue
                    self._running_tasks.remove(p)
                    print(f'Removed finished process: {p}')

                    self.logfile = p[key]['log']
                    self._logcsv()
                    if self.logcsv.loc[self.idx,'complete'] != True:
                        self.tasks.append(p[key]['dem'])
                        print(f'Added incomplete process: {p}')

                else:

                    print('CONTINUE at line 498')
                    print(self.bashCmd)
                    print(self.error)
                    continue

            time.sleep(float(args.minutes * 60))


def main():

    global args

    args = argparser()

    start_time = time.time()

    arguments = args.pos
    pool = TaskProcessor(tasks = arguments)
    pool.start()
    pool.join()

    print("HAND processed for all HUCs")
    print("-----", int((time.time()-start_time)*1000), "-----")


if __name__ == "__main__":
    main()


