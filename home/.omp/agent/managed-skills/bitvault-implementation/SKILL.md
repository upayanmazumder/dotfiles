---
name: bitvault-implementation
description: "BitVault repo conventions: gen import paths, workspace module gotchas, golangci-lint v2 config semantics, protojson int64 quirks, verification workflow. Use before any backend change in this repo."
---

# BitVault implementation conventions

Verified conventions for the upayanmazumder/bitvault repo (contract-first, modular monolith, ADR-first).

## Import paths
- Generated stubs: `github.com/bitvault/gen/bitvault/<ctx>/v1` — NO `/go/` segment. Module `github.com/bitvault/gen` is rooted at `packages/gen/go`; buf managed mode sets go_package_prefix to the module path.
- Never hand-edit `packages/gen/`; regenerate with `task gen` (buf) and commit proto + gen together.

## Go workspace gotchas
- **Never run `go mod tidy` inside a workspace module** (services/, platform/, packages/gen/go, packages/sdk-go, apps/cli): it tries to network-fetch local workspace modules (github.com/bitvault/platform, .../gen) and fails. Use `go get <third-party>@<ver>` for new deps; go.work resolves local modules.
- `go build ./...` from the repo root fails ("directory prefix . does not contain modules"); build per-module.

## golangci-lint v2 config (.golangci.yml)
- Settings: `linters.settings.<linter>` (not top-level `linters-settings:`). Formatters: `formatters.enable`. Exclusions: `linters.exclusions.paths`.
- depguard `files:` glob semantics (gobwas): `!` negation supported; `**` cannot match an EMPTY segment mid-pattern, so `**/services/foo/**/*.go` does NOT match `services/foo/main.go` (direct child). Use end-anchored `!**/services/foo/**` for negations.
- Files matching NO rule fall into an implicit deny-all "Main" list (only $gostd allowed) — a config where rules fail to load silently denies every import. Bitvaultd (the composition root) must be negated in every cross-context rule.
- Lint is run per-module, not from the repo root.

## protojson quirks
- protojson encodes int64/double-as-int64 fields as JSON STRINGS. Any REST client (gateway responses, SDK) must tolerate number-or-string for 64-bit fields (custom UnmarshalJSON).

## Verification workflow
- Run the lite stack with `docker run --network host` (bridge networking fails in this environment): postgres:16-alpine + quay.io/minio/minio:latest, then `go run ./services/bitvaultd migrate`, then the built binary with BITVAULT_* env (BITVAULT_TIER=lite, BITVAULT_DB_DSN, BITVAULT_JWT_SECRET, BITVAULT_MINIO_*).
- Smoke test each layer end-to-end (REST curl, SDK integration test with BITVAULT_TEST_SERVER, CLI against ~/.bitvault/config).
- Stacked feature branches `feature/BV-0XX-<slug>`; Conventional-Commits message with BV ticket ids; push each.

## Cross-cutting
- bitvaultd wiring: import `_ "github.com/bitvault/services/storage/provider/minio"` (blank import registers the provider; without it NewProvider fails at startup).
- Error mapping: gRPC status codes → RFC 7807 problem-details bodies at the gateway (FailedPrecondition → 409).
- The SDK is stdlib-only (net/http + crypto/sha256 for content hashes; the server accepts any client-computed hash).
