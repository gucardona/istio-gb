#!/usr/bin/env bash
# Resumo dos JSONs do fortio: qps, média, p50, p90, p99, códigos de retorno.
cd "${1:-results}"
for f in "${@:2}"; do
  [ -s "$f" ] && jq -r --arg f "$f" '[$f, (.ActualQPS|.*10|round/10), (.DurationHistogram.Avg*1000|.*100|round/100), (.DurationHistogram.Percentiles[]|select(.Percentile==50 or .Percentile==90 or .Percentile==99)|.Value*1000|.*100|round/100), (.RetCodes|tostring)] | @tsv' "$f"
done
