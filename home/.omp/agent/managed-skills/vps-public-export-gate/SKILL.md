---
name: vps-public-export-gate
description: "Use when working on the upayanmazumder/vps repo's public-repo export/redaction pipeline: running the gate, reading which files actually block publication, or adding/validating gitleaks rules."
---

# vps public-export / redaction gate

Repo: `upayanmazumder/vps` (private). These tools live under `scripts/private/`, which is excluded from the public tree by rule.

## Run the authoritative gate

```bash
rm -rf /tmp/export-check
bash scripts/private/export-public.sh --out /tmp/export-check
echo "tree at /tmp/export-check, exit should be 1 while blockers remain"
```

The script copies the allowlisted tree, redacts the changelog, then runs the check and **refuses to hand anything over** unless the check is clean. Its output names the **source files** that must be fixed at source — that list is the number to quote ("the export gate names N files").

Do **not** quote a bare `scripts/private/check-public-redaction.sh` run as the blocker count: standalone it flags files that can never leak. `EXCLUDE_PREFIXES` in `export-public.sh` is:

```
archived/ docs/plans/ docs/reports/ scripts/private/ k8s/keel/
```

So anything under `docs/plans/` (including a deliberately private notes file) is not a blocker, and the export's own check correctly does not name it.

## Confirm the tree really is clean

```bash
find /tmp/export-check -type f | wc -l                      # ~303
grep -rlE 'discord(app)?\.com/api/webhooks' /tmp/export-check   # expect nothing
ls /tmp/export-check/docs/plans/ 2>/dev/null                # expect: does not exist
```

## Adding or validating a gitleaks rule

`.gitleaks.toml` uses `[extend] useDefault = true` plus `[[allowlists]]`. A `[[rules]]` block **must sit above `[extend]`**, or TOML nests it as `extend.rules` and it silently never applies. Validate the file parses first:

```bash
python3 -c "import tomllib,pathlib; d=tomllib.loads(pathlib.Path('.gitleaks.toml').read_text()); print([r['id'] for r in d.get('rules',[])], len(d.get('allowlists',[])))"
```

CI pins the version and the invocation; match it exactly or path allowlists will not match (they test the path *as reported*):

```bash
# after dropping a planted fake webhook in /tmp/gl-test  -> expect exactly 1 hit
docker run --rm -v /tmp/gl-test:/repo -w /repo -v "$PWD/.gitleaks.toml:/repo/.gitleaks.toml:ro" \
  zricethezav/gitleaks:v8.30.1 dir . --config .gitleaks.toml --no-banner
# the real tree -> expect "no leaks found", rc=0
docker run --rm -v "$PWD:/repo" -w /repo zricethezav/gitleaks:v8.30.1 dir . --config .gitleaks.toml --redact --no-banner
```

Both directions matter: a rule that fires on a planted credential AND reports clean on the real tree. A false positive breaks CI's `secret-scan`; a rule that never fires is decoration.

## Hard rules while doing this

- Never print a secret value, a webhook token, or a workstation key path in shared output. Mask with `sed -E 's#(discord(app)?\.com/api/webhooks/[0-9]+/)\S+#\1<REDACTED>#g'`.
- Never add an allowlist to hide a live credential. An allowlist for an accepted, documented exception (the VCAP Helm values) is different, and SEC-003 removes it.
- Never fix a hit by editing the exported copy — the next export reproduces it, and the private repo is the one that has to be right.
- `sops -d --output-type json` always emits a JSON **array**. When re-encrypting a multi-document file, dump with `yaml.safe_dump_all`, and encrypt AT a path matching `.sops.yaml` (a `/tmp` path fails with "no matching creation rules found"). Hash-compare every pre-existing value before/after.
