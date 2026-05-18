# Variant bundle example

A complete, portable session-apply bundle that rebrands a stable
package as an experimental variant. The pattern generalizes to any
"fork the release into a sub-channel" workflow: a different package
name, a bumped version with rewritten dep pins, swapped data and
config files, a different suite.

## Layout

```
variant-bundle/
├── plan.json     # the manifest
├── data.bin      # NOT checked in; supplied per-build
└── config.json   # NOT checked in; supplied per-build
```

Relative paths inside `plan.json` are resolved against this directory,
so the bundle can be moved anywhere and the manifest still works.

## Running

Start with any `example-app_1.0.0_amd64.deb` whose dep field contains
`example-helper (= 1.0.0)`. The plan assumes:

* a stable channel package called `example-app` at version `1.0.0`
* a data file at `/var/lib/example/data.bin`
* a config file at `/etc/example/config.json`

```bash
deb-toolkit session open  example-app_1.0.0_amd64.deb /tmp/session
deb-toolkit session apply /tmp/session ./variant-bundle/plan.json
deb-toolkit session save  /tmp/session example-app-variant_2.0.0_amd64.deb --verify
```

## What the plan does

1. **Remove the existing data file.** The variant ships different
   payload bytes at the same path.
2. **Insert the new data file** from the bundle. The relative path
   `./data.bin` resolves against the bundle directory, not the cwd.
3. **Replace the config file** with the variant's version. `replace`
   uses a glob in package-path space — a single file in this case,
   but the verb also works against `/etc/example/*.json` for bulk
   swaps.
4. **Rename the package** to `example-app-variant` so it can be
   uploaded alongside the unmodified `example-app`.
5. **Reversion to 2.0.0 with `update_deps: true`.** The new version
   string lands in `Version:`, and every `example-* (= 1.0.0)` pin in
   the dep fields gets rewritten to `(= 2.0.0)`. Loose constraints
   like `libssl3 (>= 3.0.0)` are intentionally left untouched — they
   still describe a valid range against the bumped version.
6. **Flip the suite** to `experimental` so apt clients on that channel
   pick it up.
7. **Three `read-field` assertions** as a backstop against regressions
   in the verbs themselves — if `rename-package`, `reversion`, or
   `replace-suite` ever silently no-op'd, one of these would fail
   before the package gets signed and shipped.

## Adapting this template

The bundle is intentionally generic. To use it for a real project:

* Rename the bundle directory and update internal paths
  (`/var/lib/example/...` → wherever your project actually stores
  state).
* Swap `example-helper (= 1.0.0)` for the dep pins your real package
  uses; `update_deps: true` will rewrite anything matching the
  current `Version:` value.
* Drop in your own `data.bin` and `config.json` (or rename them and
  update the references in `plan.json`).
