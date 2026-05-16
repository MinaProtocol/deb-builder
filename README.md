# deb-toolkit

A small Rust CLI for building, signing, and verifying Debian packages.

## CLI

```
deb-toolkit build         --build-dir … --output-dir … --package-name … --version … \
                          --suite … --codename …   [+ optional metadata]
deb-toolkit sign          --deb … --key …
deb-toolkit verify content --deb …  [+ optional metadata]
deb-toolkit verify signature <deb> [--key <path|url>]
deb-toolkit lookup sign-key <deb>
```

Run `deb-toolkit <subcommand> --help` for the full flag list.

## Build

```
cargo build --release
./target/release/deb-toolkit --help
```

## Test

```
cargo test
```

Unit tests run anywhere. The two integration tests under `tests/` need
`fakeroot`, `dpkg-deb`, `debsigs`, `debsig-verify`, and `gpg` on PATH and
are skipped (with a printed note) on systems without them.

## Tools shelled out to

`fakeroot dpkg-deb`, `debsigs`, `debsig-verify`, `gpg` (tests), `curl`.

## Known limitation

The control-file template emits a fixed set of properties: `Package`,
`Version`, `Architecture`, `Maintainer`, `Section`, `Priority`, `Homepage`,
`Installed-Size`, `Source`, `Suite`, `Codename`, `License`.  `Depends`,
`Suggests`, `Recommends`, `Pre-Depends`, `Conflicts`, `Replaces`, `Provides`,
`Vendor`, and `Authors` are accepted on the CLI and validated by
`verify content`, but are not yet written to `DEBIAN/control` — to be
addressed in a follow-up.

## License

Apache-2.0
