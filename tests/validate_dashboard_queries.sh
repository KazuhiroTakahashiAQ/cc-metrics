#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_DIR="${ROOT_DIR}/grafana/dashboards"
PROM_URL="${PROM_URL:-http://localhost:9090}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

dashboard_metrics=()
prom_queries=()
loki_queries=()

while IFS= read -r file; do
  while IFS=$'\t' read -r uid expr; do
    [[ -z "${expr}" ]] && continue
    case "${uid}" in
      prometheus)
        prom_queries+=("${expr}")
        while IFS= read -r metric; do
          [[ -z "${metric}" ]] && continue
          dashboard_metrics+=("${metric}")
        done < <(printf '%s\n' "${expr}" | grep -oE 'claude_code_[A-Za-z0-9_]+' | sort -u)
        ;;
      loki)
        loki_queries+=("${expr}")
        ;;
    esac
  done < <(
    jq -r '.panels[]? as $p | ($p.targets // [])[]? | [(.datasource.uid // $p.datasource.uid // ""), (.expr // "")] | @tsv' "${file}"
  )
done < <(find "${DASHBOARD_DIR}" -maxdepth 1 -type f -name '*.json' | sort)

dashboard_metrics=($(printf '%s\n' "${dashboard_metrics[@]}" | sort -u))

expected_metrics=(
  claude_code_active_time_seconds_total
  claude_code_code_edit_tool_decision_total
  claude_code_commit_count_total
  claude_code_cost_usage_USD_total
  claude_code_lines_of_code_count_total
  claude_code_pull_request_count_total
  claude_code_session_count_total
  claude_code_token_usage_tokens_total
)

missing_from_spec=()
for metric in "${dashboard_metrics[@]}"; do
  if [[ ! " ${expected_metrics[*]} " =~ (^|[[:space:]])"${metric}"($|[[:space:]]) ]]; then
    missing_from_spec+=("${metric}")
  fi
done

if ((${#missing_from_spec[@]} > 0)); then
  echo "Dashboard references unknown Claude Code metrics:" >&2
  printf '  %s\n' "${missing_from_spec[@]}" >&2
  exit 1
fi

normalize_query() {
  local query="$1"
  query="${query//\$__range/1h}"
  query="${query//\$__interval/5m}"
  printf '%s' "${query}"
}

if curl -fsS "${PROM_URL}/-/healthy" >/dev/null 2>&1; then
  for query in "${prom_queries[@]}"; do
    normalized_query="$(normalize_query "${query}")"
    curl -fsSG "${PROM_URL}/api/v1/query" \
      --data-urlencode "query=${normalized_query}" >/dev/null
  done
fi

if curl -fsS "${LOKI_URL}/ready" >/dev/null 2>&1; then
  for query in "${loki_queries[@]}"; do
    normalized_query="$(normalize_query "${query}")"
    curl -fsSG "${LOKI_URL}/loki/api/v1/query" \
      --data-urlencode "query=${normalized_query}" >/dev/null
  done
fi

echo "Dashboard metric queries are valid."
