---
name: diagnose-competing-controller-churn
description: "Use when a Kubernetes workload's pods are constantly replaced or a Deployment keeps rolling (\"keeps crashing/restarting\") although the container itself never crashes — i.e. two reconcilers fight over the same field. Covers distinguishing crash from recreate, quantifying churn, and identifying the competing writers."
---

# Diagnose a workload that is being recreated, not crashing

Symptom: user says "X keeps crashing/restarting". First split the two meanings.

## 1. Crash vs recreate

```bash
kubectl -n NS get pods -l app=X            # RESTARTS 0 + small AGE = recreated, not crashing
kubectl -n NS logs deploy/X --tail=50      # clean startup + 200s on /health = the process is fine
kubectl -n NS get events --sort-by=.lastTimestamp | tail -30   # look for Readiness/Killing pairs
```

Small AGE with `RESTARTS 0` and a healthy log means the **Deployment's pod template is being rewritten**;
Kubernetes then replaces the pod. Do not go looking for app bugs.

## 2. Quantify (do this before theorising)

With Prometheus/kube-state-metrics, per namespace/deployment:

```promql
count(count by (pod) (count_over_time(kube_pod_info{namespace="NS"}[6h])))                       # distinct pods
changes(kube_deployment_status_observed_generation{namespace="NS",deployment="X"}[6h])          # template rewrites
max_over_time(kube_deployment_status_replicas_unavailable{namespace="NS",deployment="X"}[6h])   # real downtime?
```

Compare against a sibling app that is *not* misbehaving — that contrast is what makes the number
meaningful (e.g. 306 pods/6 h vs 1 for the neighbour).

## 3. Find the writers

```bash
kubectl -n NS get OBJECT -o json --show-managed-fields | jq -r '.metadata.managedFields[] | "\(.manager) \(.operation) \(.time)"'
```

Two managers on the same object whose timestamps keep advancing = two controllers writing it.
`metadata.generation` climbing is spec churn (a manager writing only `status` does not bump it).

## 4. Catch a short-lived state

A field written and reverted within seconds is invisible to anything coarser than a few seconds.
Poll at ~3 s and hash the spec so each distinct state gets a name:

```bash
kubectl -n NS get OBJECT -o json | jq .spec > a.json
# loop: dump .spec -> sha256sum; on change, diff a.json b.json and print both hashes
```

Two hashes alternating (with/without the field) is proof of a write/revert fight, and the period
between alternations is the slower writer's interval.

## 5. Confirm each side

- Check the fast writer's own log: it repeating the *same* change every cycle ("Setting new image to
  <same digest>") means its write never persists.
- Check the reverter: a GitOps controller with `selfHeal`/SSA reverts any field the git manifest does
  not carry, usually within seconds. `kubectl -n argocd get app X -o jsonpath='{.spec.syncPolicy}'`.

## 6. Fix the ownership, don't suppress the diff

Pick one authoritative writer. Preferred: make the out-of-band writer commit to git (e.g.
argocd-image-updater `write-back-method: git:secret:...`, plus `helmvalues:<path>` as
`write-back-target` for Helm sources) so the desired state is visible and the GitOps controller stops
seeing drift. `ignoreDifferences`/self-heal-disabling hides the conflict and leaves live state
different from git — use only when a field is genuinely owned out-of-band (e.g. KEDA replicas).

## 7. Verify with the same metrics

Re-run step 2 over a window entirely after the fix: template changes should equal exactly the fix's
own rollout (often 1) and `replicas_unavailable` 0, plus one stable pod age that keeps growing.
