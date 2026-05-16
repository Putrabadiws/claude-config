---
description: Production environment safety rules
---

# Production Environment Safety

Applies to any cluster, deployment, or environment marked prod (*-prod, production namespaces).

## Before mutating prod
- Verify current kubectl context and namespace explicitly before apply/patch/delete
- Run helm with `--dry-run` first; diff against expected before real apply
- For PVC / StatefulSet / storage changes: confirm impact (recreation, downtime, data loss) before proceeding
- For ConfigMap/Secret changes: grep consumers across charts before pushing

## Drift discipline
- If chart-vs-cluster drift is found, do NOT silently sync chart to match cluster. Surface the drift, identify which side is correct, then update the wrong side deliberately.
- Live patches in prod must be backported to the chart in the same session, with a commit message noting "patched live, syncing chart".

## Don't
- Don't run destructive ops (rollout undo, delete, scale 0) on prod without explicit user instruction in the same session
- Don't trust ConfigMap defaults blindly — env vars often override; check the actual deployed values
