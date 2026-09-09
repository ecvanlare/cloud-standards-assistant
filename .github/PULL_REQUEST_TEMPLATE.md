## What this PR does

<!-- One or two sentences. Which phase/ticket does this correspond to? (e.g. AZP-2) -->

## Checklist

- [ ] `terraform fmt` / `terraform validate` pass (if this touches `terraform/`)
- [ ] Ran locally / tested against dev environment
- [ ] Updated relevant docs (`README.md`, `docs/ARCHITECTURE.md`, `docs/INFRASTRUCTURE.md`) if behavior or architecture changed
- [ ] No secrets or keys committed
- [ ] Golden eval set / regression tests still pass (if this touches agents, tools, or retrieval): `python3 eval/scripts/validate-golden-set.py` (and live `./eval/scripts/run-regression.sh` with `RUN_LIVE_EVAL=1` when Azure creds are available)
- [ ] Observability: App Insights / Control Plane still wired if this touches agents or Functions (see `docs/OBSERVABILITY.md`)

## Notes

<!-- Anything the reviewer (future you) should know -->
