#!/bin/zsh

function kill_clickhouse() {
    ps -ef | grep clickhouse | grep -v grep | awk '{print $2}' | xargs kill -9
}

function start_metastore() {
}