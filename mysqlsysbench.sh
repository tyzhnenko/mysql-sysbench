#!/bin/bash
###############################
# Sysbench v0.4.12 shell script for MySQL benchmark
# (c) Tyzhnenko Dmitry
# Thanks for George Liu (eva2000) for idea
###############################


MYUSER=""
MYPASS=""
MYSOCKET="/var/run/mysqld/mysqld.sock"
THREADS="1 2 4 8 12 16 24 32 48 64"
ROWS=10000000
MAXROWS=${ROWS}0
REQUESTS=100000
ELEVATORS="cfq deadline noop"
DEF_ELEVATOR="cfq"
FILTER="Number of threads|transactions:|deadlocks:|read\/write requests|total time:"
EGREP=/bin/egrep
DEV=sda


prepare_table ()
{

sysbench --test=oltp \
    --init-rng=1 \
    --num-threads=1 \
    --mysql-table-engine=$ENGINE \
    --oltp-table-size=$ROWS \
    --mysql-user=$MYUSER \
    --mysql-password=$MYPASS \
    --mysql-socket=$MYSOCKET \
    --max-requests=$REQUESTS \
    --myisam-max-rows=$MAXROWS \
    --oltp-read-only \
    --oltp-dist-type=uniform prepare

}

cleanup_table () 
{

sysbench --test=oltp \
    --init-rng=1 \
    --num-threads=1 \
    --mysql-table-engine=$ENGINE \
    --oltp-table-size=$ROWS \
    --mysql-user=$MYUSER \
    --mysql-password=$MYPASS \
    --mysql-socket=$MYSOCKET \
    --max-requests=$REQUESTS \
    --oltp-read-only \
    --oltp-dist-type=uniform cleanup

}

bench_rw ()
{

sysbench --test=oltp \
    --init-rng=1 \
    --num-threads=$COUNT \
    --oltp-table-size=$ROWS \
    --mysql-user=$MYUSER \
    --mysql-password=$MYPASS \
    --mysql-socket=$MYSOCKET \
    --max-requests=$REQUESTS \
    --oltp-read-only=off \
    --oltp-dist-type=uniform run | $EGREP "$FILTER"

}

bench_ro ()
{

sysbench --test=oltp \
    --init-rng=1 \
    --num-threads=$COUNT \
    --oltp-table-size=$ROWS \
    --mysql-user=$MYUSER \
    --mysql-password=$MYPASS \
    --mysql-socket=$MYSOCKET \
    --max-requests=$REQUESTS \
    --oltp-read-only \
    --oltp-dist-type=uniform run | $EGREP "$FILTER"

}

change_elevator ()
{
    echo "# Set scheduler to $ELEVATOR"
    echo "$ELEVATOR" > /sys/block/${DEV}/queue/scheduler

}

ro_threads_test ()
{
echo "## Start benchmark threads read only test"
for COUNT in $THREADS
do
    bench_ro
done
echo "## Finish benchmark threads read only test"
}

rw_threads_test ()
{
echo "## Start benchmark threads read write test"
for COUNT in $THREADS
do
    bench_rw
done
echo "## Finish benchmark threads read write test"
}

elevator_ro_threads_test ()
{
echo "# Start elevators read only test"
for ELEVATOR in $ELEVATORS; do
    change_elevator
    ro_threads_test
done
echo "Set to default elevator - $DEF_ELEVATOR"
ELEVATOR=$DEF_ELEVATOR
change_elevator
echo "# Finish elevators read only test"
}

elevator_rw_threads_test ()
{
echo "# Start elevators read write test"
for ELEVATOR in $ELEVATORS; do
    change_elevator
    rw_threads_test
done
echo "Set to default elevator - $DEF_ELEVATOR"
ELEVATOR = $DEF_ELEVATOR
change_elevator
echo "# Finish elevators read write test"
}

elevator_rorw_threads_test ()
{
echo "# Start elevators read only and read write test"
for ELEVATOR in $ELEVATORS; do
    change_elevator
    ro_threads_test
    rw_threads_test
done
echo "Set to default elevator - $DEF_ELEVATOR"
ELEVATOR = $DEF_ELEVATOR
change_elevator
echo "# Finish elevators read only and read write test"
}

check_su ()
{
    if [ "$(whoami)" == "root" ];
    then
        echo "Superuser - OK"
    else
        echo "You must run elevator test from superuser"
        exit 1
    fi
}
case "$1" in
--myisam-prepare)
    
    echo "## Start prepare MyISAM tables"
    ENGINE=myisam
    prepare_table
    echo "## Finish prepare MyISAM tables"

;;
--myisam-cleanup)
    
    echo "## Start cleanup MyISAM tables"
    ENGINE=myisam
    cleanup_table
    echo "## Finish cleanup MyISAM tables"

;;
--innodb-prepare)
    
    echo "## Start prepare InnoDB tables"
    ENGINE=innodb
    prepare_table
    echo "## Finish cleanup InnoDB tables"

;;
--innodb-cleanup)
    
    echo "## Start prepare InnoDB tables"
    ENGINE=innodb
    cleanup_table
    echo "## Finish cleanup InnoDB tables"

;;
--ro-run)
    ro_threads_test
;;
--rw-run)
    rw_threads_test
;;
--rorw-run)
echo "# Start read only/read write benchmarks"
    ro_threads_test
    rw_threads_test
echo "# Finish read only/read write benchmarks"
;;
--elevator-ro-run)
    check_su
    elevator_ro_threads_test
;;
--elevator-rw-run)
    check_su
    elevator_rw_threads_test
;;
--elevator-rorw-run)
echo "# Start read only/read write benchmarks"
    check_su
    elevator_rorw_threads_test
echo "# Finish read only/read write benchmarks"
;;
esac
