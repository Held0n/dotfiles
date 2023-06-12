#!/bin/zsh

function kill_clickhouse() {
    if [[ $(ps -ef | grep clickhouse | grep -v grep | awk '{print $2}') ]]; then
        ps -ef | grep clickhouse | grep -v grep | awk '{print $2}' | xargs kill -9
    fi
}

function redkv-cli() {
    local index=$1
    [[ $1 ]] || index=0;
    host=$(cat /data/clickhouse/kv_endpoints.json | jq -r ".endpoints[$index].address" | cut -d : -f 1)
    port=$(cat /data/clickhouse/kv_endpoints.json | jq -r ".endpoints[$index].address" | cut -d : -f 2)
    redis-cli -h $host -p $port
}

function start_metastore() {
    local metastore_home="/root/project/clickhouse-metastore"
    cd $metastore_home
    mvn clean compile 
    mvn spring-boot:run &
}
