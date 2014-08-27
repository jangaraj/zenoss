# proof of concept

find /opt/zenoss/perf/Devices -type f -name '*.rrd' -exec bash -c '
    rrdvalue=`rrdtool fetch --start=now-1min --end=now-1min "$1" AVERAGE | tail -n 1 | awk "{print $$2}"`
    if [ $rrdvalue = "nan" ]; then
        printf "FAIL: $1\n"
    else
        printf "PASS: $1 - value %f\n" $rrdvalue
    fi' -- {} \;