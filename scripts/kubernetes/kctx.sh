#!/usr/bin/env bash
# kctx.sh -- interactive-free context/namespace switcher (kubectx/kubens
# equivalent, without the extra dependency). Reuses kubectl's own config, so
# it always reflects reality -- no separate state file to drift.
#
# Usage:
#   kctx.sh                  # list contexts, current marked with *
#   kctx.sh <context>        # switch context
#   kctx.sh ns                # list namespaces in current context
#   kctx.sh ns <namespace>    # switch namespace in current context
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 1; }

case "${1:-}" in
  "")
    current="$(kubectl config current-context 2>/dev/null || echo "")"
    kubectl config get-contexts -o name | while read -r ctx; do
      if [ "$ctx" = "$current" ]; then echo "* $ctx"; else echo "  $ctx"; fi
    done
    ;;
  ns)
    if [ -n "${2:-}" ]; then
      kubectl config set-context --current --namespace="$2"
      echo "namespace -> $2"
    else
      current_ns="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || echo default)"
      kubectl get namespaces -o name | sed 's@namespace/@@' | while read -r ns; do
        if [ "$ns" = "$current_ns" ]; then echo "* $ns"; else echo "  $ns"; fi
      done
    fi
    ;;
  *)
    kubectl config use-context "$1"
    ;;
esac
