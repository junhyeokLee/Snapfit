# Template One-Click Release

## Local (recommended)

```bash
cd /Users/devsheep/SnapFit/SnapFit
make template-release HANDOFF=assets/templates/save_the_date_handoff.json PAGES=12 BASE_URL=http://54.253.3.176
```

- Runs: store build -> release gate -> publish
- Fails fast if metadata/font ratios/assets are invalid

Dry-run only:

```bash
make template-release-dry HANDOFF=assets/templates/save_the_date_handoff.json PAGES=12
```

## GitHub Actions (button)

Workflow: `.github/workflows/template-release.yml`

Required repo secrets:
- `SNAPFIT_API_BASE_URL`
- `SNAPFIT_PUSH_ADMIN_KEY`

Run `Template Release` via `workflow_dispatch` and set:
- `handoff_path`
- `pages`
- `publish=true`

## Important quality gate

Release gate now blocks publish when:
- `metadata.designWidth/designHeight` missing
- text layer has no `textStyle.fontSizeRatio`
- pages/images/url checks fail
