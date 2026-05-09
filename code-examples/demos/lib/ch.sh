#!/usr/bin/env bash
# Source this file for ch_single / ch_node / ch_cluster helpers.
# Assumes the relevant docker-compose stack is already up.

set -euo pipefail

CH_CLUSTER_NAME="${CH_CLUSTER_NAME:-clickhouse_cluster}"

# Run query against the single-node container.
ch_single() {
    local q="$1"
    docker exec -i clickhouse-single \
        clickhouse-client --multiquery --query "$q"
}

# Run query against a specific cluster node, e.g. ch_node s1r1 "SELECT 1"
ch_node() {
    local node="$1" q="$2"
    docker exec -i "clickhouse-${node}" \
        clickhouse-client --multiquery --query "$q"
}

# Run query against any cluster node (default s1r1). Useful for distributed reads.
ch_cluster() {
    local q="$1" node="${2:-s1r1}"
    ch_node "$node" "$q"
}

# Run query against every cluster node and print "<node>: <result>" lines.
ch_each() {
    local q="$1"
    for node in s1r1 s1r2 s2r1 s2r2 s3r1 s3r2; do
        printf '%s: ' "$node"
        ch_node "$node" "$q" | tr '\n' ' '
        printf '\n'
    done
}

# Pretty print: query first, then result, then blank line.
ch_show() {
    local target="$1" q="$2"
    echo "──── $target ────"
    echo "$q"
    echo "────"
    case "$target" in
        single) ch_single "$q" ;;
        s1r1|s1r2|s2r1|s2r2|s3r1|s3r2) ch_node "${target}" "$q" ;;
        cluster) ch_cluster "$q" ;;
        *) echo "unknown target: $target" >&2; return 2 ;;
    esac
    echo
}

# Wait until the single-node container answers /ping. Useful at run.sh top.
ch_wait_single() {
    for _ in $(seq 1 30); do
        if docker exec clickhouse-single \
            wget --spider -q http://localhost:8123/ping 2>/dev/null; then
            return 0
        fi
        sleep 2
    done
    echo "clickhouse-single never came healthy" >&2
    return 1
}

ch_wait_cluster() {
    for node in s1r1 s1r2 s2r1 s2r2 s3r1 s3r2; do
        for _ in $(seq 1 30); do
            if docker exec "clickhouse-${node}" \
                wget --spider -q http://localhost:8123/ping 2>/dev/null; then
                break
            fi
            sleep 2
        done
    done
}
