#!/usr/bin/env seiscomp-python

from __future__ import absolute_import, division, print_function

import sys
import os
import time
import datetime
import calendar
import math
import stat

from getopt import gnu_getopt, GetoptError
from seiscomp import mseedlite as mseed


# ------------------------------------------------------------------------------
def read_mseed_with_delays(delaydict, reciterable):
    """
    Create an iterator which takes into account configurable realistic delays.

    This function creates an iterator which returns one miniseed record at a time.
    Artificial delays can be introduced by using delaydict.

    This function can be used to make simulations in real time more realistic
    when e.g. some stations have a much higher delay than others due to
    narrow bandwidth communication channels etc.

    A delaydict has the following data structure:
    keys: XX.ABC (XX: network code, ABC: station code). The key "default" is
    a special value for the default delay.
    values: Delay to be introduced in seconds

    This function will rearrange the iterable object which has been used as
    input for rt_simul() so that it can again be used by rt_simul but taking
    artificial delays into account.
    """
    import heapq  # pylint: disable=C0415

    heap = []
    min_delay = 0
    default_delay = 0
    if "default" in delaydict:
        default_delay = delaydict["default"]
    for rec in reciterable:
        rec_time = calendar.timegm(rec.end_time.timetuple())
        delay_time = rec_time
        stationname = f"{rec.net}.{rec.sta}"
        if stationname in delaydict:
            delay_time = rec_time + delaydict[stationname]
        else:
            delay_time = rec_time + default_delay
        heapq.heappush(heap, (delay_time, rec))
        toprectime = heap[0][0]
        if toprectime - min_delay < rec_time:
            topelement = heapq.heappop(heap)
            yield topelement
    while heap:
        topelement = heapq.heappop(heap)
        yield topelement


# ------------------------------------------------------------------------------
def rt_simul(f, speed=1.0, jump=0.0, delaydict=None):
    """
    Iterator to simulate "real-time" MSeed input

    At startup, the first MSeed record is read. The following records are
    read in pseudo-real-time relative to the time of the first record,
    resulting in data flowing at realistic speed. This is useful e.g. for
    demonstrating real-time processing using real data of past events.

    The data in the input file may be multiplexed, but *must* be sorted by
    time, e.g. using 'mssort'.
    """
    rtime = time.time()
    etime = None
    skipping = True
    record_iterable = mseed.Input(f)
    if delaydict:
        record_iterable = read_mseed_with_delays(delaydict, record_iterable)
    for rec in record_iterable:
        if delaydict:
            rec_time = rec[0]
            rec = rec[1]
        else:
            rec_time = calendar.timegm(rec.end_time.timetuple())
        if etime is None:
            etime = rec_time

        if skipping:
            if (rec_time - etime) / 60.0 < jump:
                continue

            etime = rec_time
            skipping = False

        tmax = etime + speed * (time.time() - rtime)
        ms = 1000000.0 * (rec.nsamp / rec.fsamp)
        last_sample_time = rec.begin_time + datetime.timedelta(microseconds=ms)
        last_sample_time = calendar.timegm(last_sample_time.timetuple())
        if last_sample_time > tmax:
            time.sleep((last_sample_time - tmax + 0.001) / speed)
        yield rec


# ------------------------------------------------------------------------------
def usage():
    print(
        """Usage:
  msrtsimul [options] file

miniSEED real-time playback and simulation

msrtsimul reads sorted (and possibly multiplexed) miniSEED files and writes
individual records in pseudo-real-time. This is useful e.g. for testing and
simulating data acquisition. Output is
$SEISCOMP_ROOT/var/run/seedlink/mseedfifo unless --seedlink or -c is used.

Verbosity:
  -h, --help            Display this help message
  -v, --verbose         Verbose mode

Playback:
  -j, --jump            Minutes to skip (float).
  -c, --stdout          Write on standard output.
  -d, --delays          Seconds to add as artificial delays.
      --seedlink        Choose the seedlink module name. Useful if a seedlink
                        alias or non-standard names are used. Replaces
                        'seedlink' in the standard mseedfifo path.
  -m  --mode            Choose between 'realtime' and 'historic'.
  -s, --speed           Speed factor (float).
      --test            Test mode.
  -u, --unlimited       Allow miniSEED records which are not 512 bytes

Examples:
Play back miniSEED waveforms in real time with verbose output
  msrtsimul -v data.mseed

Play back miniSEED waveforms in real time skipping the first 1.5 minutes
  msrtsimul -j 1.5 data.mseed
"""
    )


# ------------------------------------------------------------------------------
def main():
    py2 = sys.version_info < (3,)

    ifile = sys.stdin if py2 else sys.stdin.buffer
    verbosity = 0
    speed = 1.0
    jump = 0.0
    test = False
    ulimited = False
    seedlink = "seedlink"
    mode = "realtime"

    try:
        opts, args = gnu_getopt(
            sys.argv[1:],
            "cd:s:j:vhm:u",
            [
                "stdout",
                "delays=",
                "speed=",
                "jump=",
                "test",
                "verbose",
                "help",
                "mode=",
                "seedlink=",
                "unlimited"
            ],
        )
    except GetoptError:
        usage()
        return 1

    out_channel = None
    delays = None

    for flag, arg in opts:
        if flag in ("-c", "--stdout"):
            out_channel = sys.stdout if py2 else sys.stdout.buffer
        elif flag in ("-d", "--delays"):
            delays = arg
        elif flag in ("-s", "--speed"):
            speed = float(arg)
        elif flag in ("-j", "--jump"):
            jump = float(arg)
        elif flag in ("-m", "--mode"):
            mode = arg
        elif flag == "--seedlink":
            seedlink = arg
        elif flag in ("-v", "--verbose"):
            verbosity += 1
        elif flag == "--test":
            test = True
        elif flag in ("-u", "--unlimited"):
            ulimited = True
        else:
            usage()
            if flag in ("-h", "--help"):
                return 0
            return 1

    if len(args) == 1:
        if args[0] != "-":
            try:
                ifile = open(args[0], "rb")
            except IOError as e:
                print(
                    f"could not open input file '{args[0]}' for reading: {e}",
                    file=sys.stderr,
                )
                sys.exit(1)
    elif len(args) != 0:
        usage()
        return 1

    if out_channel is None:
        try:
            sc_root = os.environ["SEISCOMP_ROOT"]
        except KeyError:
            print("SEISCOMP_ROOT environment variable is not set", file=sys.stderr)
            sys.exit(1)

        mseed_fifo = os.path.join(sc_root, "var", "run", seedlink, "mseedfifo")
        if verbosity:
            print(f"output data to {mseed_fifo}", file=sys.stderr)

        if not os.path.exists(mseed_fifo):
            print(
                f"""\
ERROR: {mseed_fifo} does not exist.
In order to push the records to SeedLink, \
it needs to run and must be configured for real-time playback.
""",
                file=sys.stderr,
            )
            sys.exit(1)

        if not stat.S_ISFIFO(os.stat(mseed_fifo).st_mode):
            print(
                f"""\
ERROR: {mseed_fifo} is not a named pipe
Check if SeedLink is running and configured for real-time playback.
""",
                file=sys.stderr,
            )
            sys.exit(1)

        try:
            out_channel = open(mseed_fifo, "wb")
        except Exception as e:
            print(str(e), file=sys.stderr)
            sys.exit(1)

    try:
        delaydict = None
        if delays:
            delaydict = {}
            try:
                f = open(delays, "r")
                for line in f:
                    content = line.split(":")
                    if len(content) != 2:
                        raise ValueError(
                            f"Could not parse a line in file {delays}: {line}\n"
                        )
                    delaydict[content[0].strip()] = float(content[1].strip())
            except Exception as e:
                print(f"Error reading delay file {delays}: {e}", file=sys.stderr)

        inp = rt_simul(ifile, speed=speed, jump=jump, delaydict=delaydict)
        stime = time.time()

        time_diff = None
        print(
            f"Starting msrtsimul at {datetime.datetime.utcnow()}",
            file=sys.stderr,
        )
        for rec in inp:
            if rec.size != 512 and not ulimited:
                print(
                    f"Skipping record of {rec.net}.{rec.sta}.{rec.loc}.{rec.cha} \
starting on {str(rec.begin_time)}: length != 512 Bytes.",
                    file=sys.stderr,
                )
                continue
            if time_diff is None:
                ms = 1000000.0 * (rec.nsamp / rec.fsamp)
                time_diff = (
                    datetime.datetime.utcnow()
                    - rec.begin_time
                    - datetime.timedelta(microseconds=ms)
                )
            if mode == "realtime":
                rec.begin_time += time_diff

            if verbosity:
                tdiff_to_start = time.time() - stime
                tdiff_to_current = time.time() - calendar.timegm(
                    rec.begin_time.timetuple()
                )
                nslc = f"{rec.net}.{rec.sta}.{rec.loc}.{rec.cha}"
                print(
                    f"{nslc: <17} \
{tdiff_to_start: 7.2f} {str(rec.begin_time)} {tdiff_to_current: 7.2f}",
                    file=sys.stderr,
                )

            if not test:
                rec.write(out_channel, int(math.log2(rec.size)))
                out_channel.flush()

    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"Exception: {str(e)}", file=sys.stderr)
        return 1

    return 0


# ------------------------------------------------------------------------------
if __name__ == "__main__":
    sys.exit(main())
