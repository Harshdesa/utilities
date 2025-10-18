#!/usr/bin/env bash
# purge-bad-kube-contexts.sh
# Test all contexts in ~/.kube/config; delete failing contexts and (if unused) their user/cluster.
# Usage: ./purge-bad-kube-contexts.sh [--force] [--no-backup] [--timeout-secs 10] [--request-timeout 5s]
set -u

FORCE=0
DO_BACKUP=1
PROBE_TIMEOUT_SECS=10
K8S_REQUEST_TIMEOUT="5s"
KUBECONFIG_PATH="${HOME}/.kube/config"

while [[ $# -gt 0 ]]; do
case "$1" in
--force) FORCE=1; shift ;;
--no-backup) DO_BACKUP=0; shift ;;
--timeout-secs) PROBE_TIMEOUT_SECS="${2:-10}"; shift 2 ;;
--request-timeout) K8S_REQUEST_TIMEOUT="${2:-5s}"; shift 2 ;;
-h|--help)
echo "Usage: $0 [--force] [--no-backup] [--timeout-secs N] [--request-timeout DURATION]"
exit 0
;;
*) echo "Unknown arg: $1" >&2; exit 2 ;;
esac
done

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
echo "No kubeconfig at $KUBECONFIG_PATH" >&2
exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

if ! command -v kubectl >/dev/null 2>&1; then
echo "kubectl not found in PATH" >&2
exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
if (( DO_BACKUP )); then
backup="${KUBECONFIG_PATH}.${timestamp}.bak"
cp -p "$KUBECONFIG_PATH" "$backup"
echo "Backup created: $backup"
fi

# Helper: JSONPath query with context by name
ctx_jsonpath() {
local ctx="$1" field="$2"
# field is 'cluster' or 'user'
kubectl config view --raw -o jsonpath="{.contexts[?(@.name==\"${ctx}\")].context.${field}}" 2>/dev/null
}

# Helper: how many contexts reference this user/cluster?
count_contexts_for_field_val() {
local field="$1" val="$2"
# field is 'user' or 'cluster'
# Outputs count (integer)
local names
names="$(kubectl config view --raw -o jsonpath="{.contexts[?(@.context.${field}==\"${val}\")].name}" 2>/dev/null || true)"
# jsonpath returns space-separated list; empty if none
if [[ -z "${names// /}" ]]; then
echo 0
else
# shellcheck disable=SC2086
echo $names | wc -w | tr -d ' '
fi
}

current_ctx="$(kubectl config current-context 2>/dev/null || true)"
bad=()
ok=()

# List all contexts
mapfile -t contexts < <(kubectl config get-contexts -o name)

if [[ ${#contexts[@]} -eq 0 ]]; then
echo "No contexts found in kubeconfig."
exit 0
fi

echo "Testing ${#contexts[@]} context(s)..."

for ctx in "${contexts[@]}"; do
printf '• %-40s ' "$ctx"
# Try to talk to the API quickly; avoid hanging forever.
if timeout "${PROBE_TIMEOUT_SECS}"s kubectl --context "$ctx" --request-timeout="$K8S_REQUEST_TIMEOUT" get ns >/dev/null 2>&1; then
echo "OK"
ok+=("$ctx")
else
echo "FAIL (will delete)"
bad+=("$ctx")
fi
done

echo
echo "Summary: ${#ok[@]} OK, ${#bad[@]} FAIL"

if [[ ${#bad[@]} -eq 0 ]]; then
echo "Nothing to delete."
exit 0
fi

if (( ! FORCE )); then
echo
echo "About to delete the following contexts (and their users/clusters if unused):"
for c in "${bad[@]}"; do echo " - $c"; done
read -r -p "Proceed? [y/N] " ans
if [[ ! "$ans" =~ ^[Yy]$ ]]; then
echo "Aborted."
exit 0
fi
fi

for ctx in "${bad[@]}"; do
cluster="$(ctx_jsonpath "$ctx" cluster || true)"
user="$(ctx_jsonpath "$ctx" user || true)"

echo
echo "Deleting context: $ctx"
kubectl config delete-context "$ctx" >/dev/null

# If we just deleted the current context, unset it
if [[ -n "$current_ctx" && "$ctx" == "$current_ctx" ]]; then
echo "Unsetting current-context (was $current_ctx)"
kubectl config unset current-context >/dev/null
current_ctx=""
fi

# Delete user if not referenced by any remaining contexts
if [[ -n "$user" ]]; then
refs_u=$(count_contexts_for_field_val "user" "$user")
if (( refs_u == 0 )); then
echo "Deleting user: $user"
kubectl config delete-user "$user" >/dev/null || true
else
echo "User '$user' still referenced by $refs_u other context(s); skipping."
fi
fi

# Delete cluster if not referenced by any remaining contexts
if [[ -n "$cluster" ]]; then
refs_c=$(count_contexts_for_field_val "cluster" "$cluster")
if (( refs_c == 0 )); then
echo "Deleting cluster: $cluster"
kubectl config delete-cluster "$cluster" >/dev/null || true
else
echo "Cluster '$cluster' still referenced by $refs_c other context(s); skipping."
fi
fi
done

echo
echo "Done."
