#!/bin/bash

# set -e

## Platform specific variables
OS=$(uname)

THIS_FILE=$(realpath "$0")
USER=$(whoami)
WAIT_TIMEOUT=5

## Default values
PGAGROAL_PORT=2345
PORT=5432
PGPASSWORD="password"

## Already present directories
PROJECT_DIRECTORY=$(pwd)
EXECUTABLE_DIRECTORY=$(pwd)/src
TEST_DIRECTORY=$(pwd)/test

## Create directories and files
LOG_DIRECTORY=$(pwd)/log
PGCTL_LOG_FILE=$LOG_DIRECTORY/logfile
PGAGROAL_LOG_FILE=$LOG_DIRECTORY/pgaroal.log
PGBENCH_LOG_FILE=$LOG_DIRECTORY/pgbench.log

POSTGRES_OPERATION_DIR=$(pwd)/pgagroal-postgresql
DATA_DIRECTORY=$POSTGRES_OPERATION_DIR/data

PGAGROAL_OPERATION_DIR=$(pwd)/pgagroal-testsuite
CONFIGURATION_DIRECTORY=$PGAGROAL_OPERATION_DIR/conf

########################### UTILS ############################
is_port_in_use() {
    local port=$1
    local status=1
    if [[ "$OS" =~ Linux ]]; then
        netstat -tuln | grep $port > /dev/null 2>&1
        status=$?
    elif [[ "$OS" == "Darwin" ]]; then
        lsof -i:$port > /dev/null 2>&1
        status=$?
    fi
    return $status
}

next_available_port() {
    local port=$1
    while true; do
        is_port_in_use $port
        if [ $? -ne 0 ]; then
            return 0
        else
            port=$((port + 1))
        fi
    done
}

wait_for_server_ready() {
    local start_time=$SECONDS
    local port=$1
    while true; do
        pg_isready -h localhost -p $port
        if [ $? -eq 0 ]; then
            echo "pgagroal is ready for accepting responses"
            return 0
        fi
        if [ $(($SECONDS - $start_time)) -gt $WAIT_TIMEOUT ]; then
            echo "waiting for server timed out"
            return 1
        fi

        # Avoid busy-waiting
        sleep 1
    done
}

verify_configured_port () {
    local ports_configured=$(awk '
        /^\[pgagroal\]/ { skip=1; next }
        /^\[/ { skip=0 }
        !skip && /^port[[:space:]]*=/ { print $NF }
    ' "$CONFIGURATION_DIRECTORY/pgagroal.conf")
    for port in $ports_configured; do  ## check if the port is correctly configured
        if [ "$port" -ne "$PORT" ]; then
            return 1
        fi
    done
    if awk '/^\[pgagroal\]/ {found=1} found && /^log_type *= *file/ {print "FOUND"; exit}' "$CONFIGURATION_DIRECTORY/pgagroal.conf" | grep -q "FOUND"; then ## check if log_type is file
        awk -v new_path="$PGAGROAL_LOG_FILE" '
            /^\[pgagroal\]/ {found=1}
            found && /^log_path *=/ {sub(/=.*/, "= " new_path)}
            {print}
        ' "$CONFIGURATION_DIRECTORY/pgagroal.conf" > temp.ini && mv temp.ini "$CONFIGURATION_DIRECTORY/pgagroal.conf"
    else
        return 1
    fi

    return 0
}
##############################################################

############### CHECK POSTGRES DEPENDENCIES ##################
check_inidb() {
    if which initdb > /dev/null 2>&1; then
        echo "check initdb in path ... ok"
        return 0
    else
        echo "check initdb in path ... not present"
        return 1
    fi
}

check_pgbench() {
    if which pgbench > /dev/null 2>&1; then
        echo "check pgbench in path ... ok"
        return 0
    else
        echo "check pgbench in path ... not present"
        return 1
    fi
}

check_port() {
    is_port_in_use $PORT
    if [ $? -ne 0 ]; then
        echo "check port ... $PORT"
        return 0
    else
        echo "port $PORT already in use ... not ok"
        return 1
    fi
}

check_pg_ctl() {
    if which pg_ctl > /dev/null 2>&1; then
        echo "check pg_ctl in path ... ok"
        return 0
    else
        echo "check pg_ctl in path ... not ok"
        return 1
    fi
}

check_psql() {
    if which psql > /dev/null 2>&1; then
        echo "check psql in path ... ok"
        return 0
    else
        echo "check psql in path ... not present"
        return 1
    fi
}

check_postgres_version() {
    version=$(psql --version | awk '{print $3}')
    major_version=$(echo "$version" | cut -d'.' -f1)
    required_major_version=$1
    if [ "$major_version" -ge "$required_major_version" ]; then
        echo "check postgresql version: $version ... ok"
        return 0
    else
        echo "check postgresql version: $version ... not ok"
        return 1
    fi
}

check_system_requirements() {
    echo -e "\e[34mCheck System Requirements \e[0m"
    echo "check system os ... $OS"
    check_inidb
    if [ $? -ne 0 ]; then
        exit 1
    fi
    check_pg_ctl
    if [ $? -ne 0 ]; then
        exit 1
    fi
    check_pgbench
    if [ $? -ne 0 ]; then
        exit 1
    fi
    check_psql
    if [ $? -ne 0 ]; then
        exit 1
    fi
    check_port
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo ""
}

initialize_log_files() {
    echo -e "\e[34mInitialize Test logfiles \e[0m"
    mkdir -p $LOG_DIRECTORY
    echo "create log directory ... $LOG_DIRECTORY"
    touch $PGAGROAL_LOG_FILE
    echo "create log file ... $PGAGROAL_LOG_FILE"
    touch $PGCTL_LOG_FILE
    echo "create log file ... $PGCTL_LOG_FILE"
    touch $PGBENCH_LOG_FILE
    echo "create log file ... $PGBENCH_LOG_FILE"
    echo ""
}
##############################################################

##################### POSTGRES OPERATIONS ####################
create_cluster() {
    local port=$1
    echo -e "\e[34mInitializing Cluster \e[0m"
    initdb -k -D $DATA_DIRECTORY 2> /dev/null
    error_out=$(sed -i "s|#unix_socket_directories = '/var/run/postgresql'|unix_socket_directories = '/tmp'|" $DATA_DIRECTORY/postgresql.conf 2>&1)
    if [ $? -ne 0 ]; then
        echo "setting unix_socket_directories ... $error_out"
        clean
        exit 1
    else
        echo "setting unix_socket_directories ... '/tmp'"
    fi
    error_out=$(sed -i "s/#port = 5432/port = $port/" $DATA_DIRECTORY/postgresql.conf 2>&1)
    if [ $? -ne 0 ]; then
        echo "setting port ... $error_out"
        clean
        exit 1
    else
        echo "setting port ... $port"
    fi
    error_out=$(sed -i "s/#max_connections = 100/max_connections = 200/" $DATA_DIRECTORY/postgresql.conf 2>&1)
    if [ $? -ne 0 ]; then
        echo "setting max_connections ... $error_out"
        clean
        exit 1
    else
        echo "setting max_connections ... 200"
    fi
    echo ""
}

initialize_hba_configuration() {
    echo -e "\e[34mCreate HBA Configuration \e[0m"
    echo "
    local   all             all                                     trust
    host    all             all             127.0.0.1/32            trust
    host    all             all             ::1/128                 trust
    host    replication     all             127.0.0.1/32            trust
    host    replication     all             ::1/128                 trust
    host    mydb            myuser          127.0.0.1/32            scram-sha-256
    host    mydb            myuser          ::1/128                 scram-sha-256
    " > $DATA_DIRECTORY/pg_hba.conf
    echo "initialize hba configuration at $DATA_DIRECTORY/pg_hba.conf ... ok"
    echo ""
}

initialize_cluster() {
    echo -e "\e[34mInitializing Cluster \e[0m"
    set +e
    pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE start
    if [ $? -ne 0 ]; then
        clean
        exit 1
    fi
    pg_isready -h localhost -p $PORT
    if [ $? -eq 0 ]; then
        echo "postgres server is accepting requests ... ok"
    else
        echo "postgres server is not accepting response ... not ok"
        clean
        exit 1
    fi
    err_out=$(psql -h localhost -p $PORT -U $USER -d postgres -c "CREATE ROLE myuser WITH LOGIN PASSWORD '$PGPASSWORD';" 2>&1)
    if [ $? -ne 0 ]; then
        echo "create role myuser ... $err_out"
        pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE stop
        clean
        exit 1
    else
        echo "create role myuser ... ok"
    fi
    err_out=$(psql -h localhost -p $PORT -U $USER -d postgres -c "CREATE DATABASE mydb WITH OWNER myuser;" 2>&1)
    if [ $? -ne 0 ]; then
        echo "create a database mydb with owner myuser ... $err_out"
        pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE stop
        clean
        exit 1
    else
        echo "create a database mydb with owner myuser ... ok"
    fi
    err_out=$(pgbench -i -s 1 -n -h localhost -p $PORT -U $USER -d postgres 2>&1)
    if [ $? -ne 0 ]; then
        echo "initialize pgbench ... $err_out"
        pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE stop
        clean
        exit 1
    else
        echo "initialize pgbench on user: $USER and database: postgres ... ok"
    fi
    set -e
    pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE stop
    echo ""
}

clean_logs() {
    if [ -d $LOG_DIRECTORY ]; then
        rm -r $LOG_DIRECTORY
        echo "remove log directory $LOG_DIRECTORY ... ok"
    else
        echo "$LOG_DIRECTORY not present ... ok"
    fi
}

clean() {
    echo -e "\e[34mClean Test Resources \e[0m"
    if [ -d $POSTGRES_OPERATION_DIR ]; then
        rm -r $POSTGRES_OPERATION_DIR
        echo "remove postgres operations directory $POSTGRES_OPERATION_DIR ... ok"
    else
      echo "$POSTGRES_OPERATION_DIR not present ... ok"
    fi

    if [ -d $PGAGROAL_OPERATION_DIR ]; then
        rm -r $PGAGROAL_OPERATION_DIR
        echo "remove pgagroal operations directory $PGAGROAL_OPERATION_DIR ... ok"
    else
        echo "$PGAGROAL_OPERATION_DIR not present ... ok"
    fi
}

##############################################################

#################### PGAGROAL OPERATIONS #####################
pgagroal_initialize_configuration() {
    echo -e "\e[34mInitialize pgagroal configuration files \e[0m"
    mkdir -p $CONFIGURATION_DIRECTORY
    echo "create configuration directory $CONFIGURATION_DIRECTORY ... ok"
    touch $CONFIGURATION_DIRECTORY/pgagroal.conf $CONFIGURATION_DIRECTORY/pgagroal_hba.conf
    cat << EOF > $CONFIGURATION_DIRECTORY/pgagroal.conf
[pgagroal]
host = localhost
port = 2345

log_type = file
log_level = debug5
log_path = $PGAGROAL_LOG_FILE

max_connections = 100
idle_timeout = 600
validation = off
unix_socket_dir = /tmp/
pipeline = 'performance'

[primary]
host = localhost
port = $PORT

EOF

    echo "create pgagroal.conf inside $CONFIGURATION_DIRECTORY ... ok"
    cat << EOF > $CONFIGURATION_DIRECTORY/pgagroal_hba.conf
host    all all all all
EOF
    echo "create pgagroal_hba.conf inside $CONFIGURATION_DIRECTORY ... ok"
    echo ""
}

execute_testcases() {
    if [ $# -eq 1 ]; then
        local config_dir=$1
        echo -e "\e[34mExecute Testcases for config:$config_dir\e[0m"
    else
        echo -e "\e[34mExecute Testcases \e[0m"
    fi

    set +e
    pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE start

    pg_isready -h localhost -p $PORT
    if [ $? -eq 0 ]; then
        echo "postgres server accepting requests ... ok"
    else
        echo "postgres server is not accepting response ... not ok"
        pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE stop
        clean
        exit 1
    fi

    $EXECUTABLE_DIRECTORY/pgagroal -c $CONFIGURATION_DIRECTORY/pgagroal.conf -a $CONFIGURATION_DIRECTORY/pgagroal_hba.conf -d
    wait_for_server_ready $PGAGROAL_PORT
    if [ $? -eq 0 ]; then
        echo "pgagroal server started in daemon mode ... ok"
    else
        echo "pgagroal server not started ... not ok"
        pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE stop
        clean
        exit 1
    fi

    ### RUN TESTCASES ###
    $TEST_DIRECTORY/pgagroal_test $PROJECT_DIRECTORY

    $EXECUTABLE_DIRECTORY/pgagroal-cli -c $CONFIGURATION_DIRECTORY/pgagroal.conf shutdown
    echo "shutdown pgagroal server ... ok"

    pg_ctl -D $DATA_DIRECTORY -l $PGCTL_LOG_FILE stop
    set -e
    echo ""
}

##############################################################

run_tests() {
    ## Postgres operations
    check_system_requirements

    initialize_log_files
    create_cluster $PORT

    initialize_hba_configuration
    initialize_cluster

    pgagroal_initialize_configuration

    if [ $# -eq 1 ]; then
        local config_dir=$1
        if [ -d $config_dir ]; then
            for entry in "$config_dir"/*; do
                entry=$(realpath $entry)
                if [[ -d "$entry" && -f "$entry/pgagroal.conf" && -f "$entry/pgagroal_hba.conf" ]]; then
                    cp $entry/pgagroal.conf $CONFIGURATION_DIRECTORY/pgagroal.conf
                    cp $entry/pgagroal_hba.conf $CONFIGURATION_DIRECTORY/pgagroal_hba.conf
                    verify_configured_port
                    if [ $? -ne 0 ]; then
                        echo "port is not configured correctly in $entry/pgagroal.conf"
                        continue
                    fi
                    execute_testcases $entry
                else
                    # warning (yellow text)
                    echo "either '$configuration_dir is not a directory'"
                    echo "or 'pgagroal.conf or pgagroal_hba.conf is not present'"
                    echo "conditions of a configuration directory are not met ... not ok"
                    echo ""
                fi
            done
        else
            echo "configuration directory $CONFIGURATION_DIRECTORY not present"
            clean
            exit 1
        fi
    else
        execute_testcases
    fi
    # clean cluster
    # clean
}

usage() {
    echo "Usage: $0 [ OPTIONS ] [ COMMAND ]"
    echo " Options:"
    echo "   -C, --config-dir <dir>  set the configuration directory"
    echo " Command:"
    echo "   clean                   clean up test suite environment"
    exit 1
}

if [ $# -eq 0 ]; then
    # If no arguments are provided, run function_without_param
    run_tests
elif [ $# -eq 1 ]; then
    if [ "$1" == "clean" ]; then
        # If the parameter is 'clean', run clean_function
        clean
        clean_logs
    else
        echo "Invalid parameter: $1"
        usage  # If an invalid parameter is provided, show usage and exit
    fi
elif [ $# -eq 2 ]; then
    if [ "$1" == "-C" ] || [ "$1" == "--config-dir" ]; then
        # If the first parameter is '-C' or '--config-dir', run function_with_param
        config_dir=$2
        run_tests $config_dir
    else
        echo "Invalid parameter: $1"
        usage  # If an invalid parameter is provided, show usage and exit
    fi
else
    usage  # If an invalid number of parameters is provided, show usage and exit
fi
