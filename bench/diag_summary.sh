#!/usr/bin/env bash
cd results/diag
printf "%-34s %8s %8s %8s %8s\n" arquivo qps p50ms p90ms p99ms
for f in *.json; do jq -r --arg f "${f%.json}" '[$f, (.ActualQPS|round), (.DurationHistogram.Percentiles[]|select(.Percentile==50 or .Percentile==90 or .Percentile==99)|.Value*1000|.*10|round/10)]|@tsv' "$f" | awk -F'\t' '{printf "%-34s %8s %8s %8s %8s\n",$1,$2,$3,$4,$5}'; done
