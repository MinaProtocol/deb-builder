# Session manifest examples

Real manifests for `deb-toolkit session apply`. See
[`docs/session-manifest.md`](../../docs/session-manifest.md) for the
full schema reference.

| Example                                    | Demonstrates                                                                                       |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| [`simple-rename.json`](simple-rename.json) | Smallest possible manifest: one mutation plus a `read-field` assertion.                            |
| [`variant-bundle/`](variant-bundle/)       | A complete portable bundle (plan + companion data files) that rebrands a stable package as a variant. |

## Running an example

```bash
# Pick whichever input .deb you want to mutate.
deb-toolkit session open ./input.deb /tmp/session

# Apply the manifest.
deb-toolkit session apply /tmp/session ./examples/manifests/simple-rename.json

# Save out.
deb-toolkit session save /tmp/session ./output.deb --verify
```

The order is always **open → apply → save**. Open and save are not
part of the manifest because they're per-invocation choices (which
input file, which output path, whether to verify) — the manifest
describes the *transformation*, not the surrounding I/O.
