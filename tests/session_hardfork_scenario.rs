//! End-to-end test of the workflow the session subsystem was built for:
//! generating a hardfork variant of an existing Mina daemon package.
//!
//! The bash `scripts/debian/session/*.sh` family on mina/develop runs this
//! exact sequence to mint `mina-hardfork-*` debs at fork time:
//!
//!   1. Open the original `mina-mainnet_<version>devnet_amd64.deb`.
//!   2. Drop in the new genesis ledgers and runtime config.
//!   3. Rename to `mina-hardfork-mainnet`.
//!   4. Reversion to the next version and rewrite `=` dep pins.
//!   5. Replace the suite (`unstable` → `umt`).
//!   6. Save and sanity-check with dpkg-deb.
//!
//! Then we re-open the saved .deb through `session` again to prove the
//! mutations survived a full open/save cycle, and we save it a second
//! time to assert the output is byte-identical (the determinism flag
//! pays off in the artifact pipeline, where reproducible packages let
//! the cache hit across rebuilds).
//!
//! Skipped when `dpkg-deb` isn't on PATH so this doesn't break dev boxes
//! that don't have Debian tooling installed.

use std::path::Path;
use std::process::Command;

fn have(cmd: &str) -> bool {
    Command::new("sh")
        .arg("-c")
        .arg(format!("command -v {} >/dev/null 2>&1", cmd))
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn run(bin: &str, args: &[&str], extra: &[&Path]) {
    let mut cmd = Command::new(bin);
    cmd.args(args);
    for p in extra {
        cmd.arg(p);
    }
    let status = cmd.status().expect("spawn deb-toolkit");
    assert!(
        status.success(),
        "deb-toolkit {} failed (status: {:?})",
        args.join(" "),
        status
    );
}

fn dpkg_info(deb: &Path) -> String {
    let out = Command::new("dpkg-deb")
        .arg("--info")
        .arg(deb)
        .output()
        .expect("dpkg-deb --info");
    assert!(out.status.success(), "dpkg-deb --info failed");
    String::from_utf8_lossy(&out.stdout).into_owned()
}

fn dpkg_contents(deb: &Path) -> String {
    let out = Command::new("dpkg-deb")
        .arg("-c")
        .arg(deb)
        .output()
        .expect("dpkg-deb -c");
    assert!(out.status.success(), "dpkg-deb -c failed");
    String::from_utf8_lossy(&out.stdout).into_owned()
}

fn read_field_via_session(bin: &str, session_dir: &Path, field: &str) -> String {
    let out = Command::new(bin)
        .args(["session", "read-field"])
        .arg(session_dir)
        .arg(field)
        .output()
        .expect("session read-field");
    assert!(
        out.status.success(),
        "session read-field {} failed: {}",
        field,
        String::from_utf8_lossy(&out.stderr)
    );
    String::from_utf8_lossy(&out.stdout).trim().to_string()
}

#[test]
fn hardfork_package_generation_scenario() {
    if !have("dpkg-deb") {
        eprintln!("skipping hardfork_package_generation_scenario: dpkg-deb not on PATH");
        return;
    }

    let bin = env!("CARGO_BIN_EXE_deb-toolkit");
    let tmp = tempfile::tempdir().unwrap();

    // --- 1. Build a fixture mina-mainnet-style .deb -----------------------
    let pkg_root = tmp.path().join("mina-mainnet-pkg");
    std::fs::create_dir_all(pkg_root.join("DEBIAN")).unwrap();
    std::fs::create_dir_all(pkg_root.join("var/lib/coda")).unwrap();
    std::fs::create_dir_all(pkg_root.join("etc/mina")).unwrap();
    std::fs::create_dir_all(pkg_root.join("usr/local/bin")).unwrap();

    std::fs::write(
        pkg_root.join("DEBIAN/control"),
        "Package: mina-mainnet\n\
         Version: 3.0.0devnet\n\
         Architecture: amd64\n\
         Maintainer: build@minaprotocol.com\n\
         Suite: unstable\n\
         Depends: mina-logproc (= 3.0.0devnet), libssl3 (>= 3.0.0), libgmp10\n\
         Description: Mina Protocol daemon (mainnet)\n",
    )
    .unwrap();

    // Pre-existing genesis ledger that the hardfork will replace.
    std::fs::write(
        pkg_root.join("var/lib/coda/genesis_ledger_devnet.tar.gz"),
        b"OLD DEVNET LEDGER\n",
    )
    .unwrap();
    std::fs::write(
        pkg_root.join("var/lib/coda/genesis_epoch_ledger_devnet.tar.gz"),
        b"OLD DEVNET EPOCH LEDGER\n",
    )
    .unwrap();
    std::fs::write(
        pkg_root.join("etc/mina/runtime_config.json"),
        "{\"network\": \"devnet\", \"protocol\": {\"k\": 290}}\n",
    )
    .unwrap();
    std::fs::write(
        pkg_root.join("usr/local/bin/mina"),
        b"#!/bin/sh\necho fake\n",
    )
    .unwrap();

    let original_deb = tmp.path().join("mina-mainnet_3.0.0devnet_amd64.deb");
    let out = Command::new("dpkg-deb")
        .args(["-Zgzip", "--build"])
        .arg(&pkg_root)
        .arg(&original_deb)
        .output()
        .expect("dpkg-deb --build");
    assert!(
        out.status.success(),
        "dpkg-deb --build failed: {}",
        String::from_utf8_lossy(&out.stderr)
    );

    // --- 2. session open --------------------------------------------------
    let session_dir = tmp.path().join("session");
    run(bin, &["session", "open"], &[&original_deb, &session_dir]);

    assert_eq!(
        read_field_via_session(bin, &session_dir, "Package"),
        "mina-mainnet"
    );
    assert_eq!(
        read_field_via_session(bin, &session_dir, "Version"),
        "3.0.0devnet"
    );

    // --- 3. Drop in new hardfork ledgers + config -------------------------
    // The bash script does this via deb-session-insert.sh + replace.
    let hf_ledger = tmp.path().join("hf_genesis_ledger.tar.gz");
    let hf_epoch = tmp.path().join("hf_genesis_epoch_ledger.tar.gz");
    std::fs::write(&hf_ledger, b"NEW HARDFORK LEDGER\n").unwrap();
    std::fs::write(&hf_epoch, b"NEW HARDFORK EPOCH LEDGER\n").unwrap();

    // The originals get *removed* (devnet → mainnet name change) before
    // the new ledgers are inserted under the canonical hardfork names.
    run(
        bin,
        &["session", "remove"],
        &[
            &session_dir,
            Path::new("/var/lib/coda/genesis_ledger_devnet.tar.gz"),
        ],
    );
    run(
        bin,
        &["session", "remove"],
        &[
            &session_dir,
            Path::new("/var/lib/coda/genesis_epoch_ledger_devnet.tar.gz"),
        ],
    );

    run(
        bin,
        &["session", "insert"],
        &[
            &session_dir,
            Path::new("/var/lib/coda/genesis_ledger.tar.gz"),
            &hf_ledger,
        ],
    );
    run(
        bin,
        &["session", "insert"],
        &[
            &session_dir,
            Path::new("/var/lib/coda/genesis_epoch_ledger.tar.gz"),
            &hf_epoch,
        ],
    );

    // Swap out the runtime config with the new hardfork one.
    let hf_runtime = tmp.path().join("hf_runtime_config.json");
    std::fs::write(
        &hf_runtime,
        "{\"network\": \"mainnet\", \"protocol\": {\"k\": 290, \"hardfork\": true}}\n",
    )
    .unwrap();
    run(
        bin,
        &["session", "replace"],
        &[
            &session_dir,
            Path::new("/etc/mina/runtime_config.json"),
            &hf_runtime,
        ],
    );

    // --- 4. Rename + reversion + suite swap -------------------------------
    run(
        bin,
        &["session", "rename-package"],
        &[&session_dir, Path::new("mina-hardfork-mainnet")],
    );
    // `reversion --update-deps` takes the *new* version and rewrites `=`
    // pins of the previously-recorded Version: field. Current Version is
    // still 3.0.0devnet at this point, so this both sets Version → 4.0.0
    // and rewrites `mina-logproc (= 3.0.0devnet)` → `(= 4.0.0)`.
    run(
        bin,
        &["session", "reversion", "--update-deps"],
        &[&session_dir, Path::new("4.0.0")],
    );

    run(
        bin,
        &["session", "replace-suite"],
        &[&session_dir, Path::new("umt")],
    );

    // Sanity-check the intermediate state via session itself.
    assert_eq!(
        read_field_via_session(bin, &session_dir, "Package"),
        "mina-hardfork-mainnet"
    );
    assert_eq!(
        read_field_via_session(bin, &session_dir, "Version"),
        "4.0.0"
    );
    assert_eq!(read_field_via_session(bin, &session_dir, "Suite"), "umt");

    // --- 5. Save with --verify --------------------------------------------
    let hf_deb = tmp.path().join("mina-hardfork-mainnet_4.0.0_amd64.deb");
    run(
        bin,
        &["session", "save", "--verify"],
        &[&session_dir, &hf_deb],
    );
    assert!(hf_deb.is_file(), "saved .deb missing");

    // --- 6. dpkg-deb assertions on the produced package -------------------
    let info = dpkg_info(&hf_deb);
    assert!(
        info.contains("Package: mina-hardfork-mainnet"),
        "Package not renamed:\n{}",
        info
    );
    assert!(info.contains("Version: 4.0.0"), "Version wrong:\n{}", info);
    assert!(info.contains("Suite: umt"), "Suite wrong:\n{}", info);
    // = pin was rewritten; >= constraint was left alone.
    assert!(
        info.contains("mina-logproc (= 4.0.0)"),
        "= pin not rewritten:\n{}",
        info
    );
    assert!(
        info.contains("libssl3 (>= 3.0.0)"),
        ">= constraint should have been left alone:\n{}",
        info
    );
    assert!(
        info.contains("libgmp10"),
        "unversioned dep dropped:\n{}",
        info
    );

    let contents = dpkg_contents(&hf_deb);
    assert!(
        contents.contains("var/lib/coda/genesis_ledger.tar.gz"),
        "new ledger missing:\n{}",
        contents
    );
    assert!(
        contents.contains("var/lib/coda/genesis_epoch_ledger.tar.gz"),
        "new epoch ledger missing:\n{}",
        contents
    );
    assert!(
        !contents.contains("genesis_ledger_devnet.tar.gz"),
        "old devnet ledger leaked into hardfork package:\n{}",
        contents
    );
    assert!(
        !contents.contains("genesis_epoch_ledger_devnet.tar.gz"),
        "old devnet epoch ledger leaked into hardfork package:\n{}",
        contents
    );
    assert!(
        contents.contains("usr/local/bin/mina"),
        "binary should have been preserved:\n{}",
        contents
    );

    // --- 7. Re-open the produced .deb and verify state survives -----------
    let reopened = tmp.path().join("reopened");
    run(bin, &["session", "open"], &[&hf_deb, &reopened]);

    assert_eq!(
        read_field_via_session(bin, &reopened, "Package"),
        "mina-hardfork-mainnet"
    );
    assert_eq!(read_field_via_session(bin, &reopened, "Version"), "4.0.0");
    assert_eq!(read_field_via_session(bin, &reopened, "Suite"), "umt");

    let reopened_ledger = std::fs::read(reopened.join("data/var/lib/coda/genesis_ledger.tar.gz"))
        .expect("reopened ledger");
    assert_eq!(reopened_ledger, b"NEW HARDFORK LEDGER\n");

    let reopened_runtime =
        std::fs::read_to_string(reopened.join("data/etc/mina/runtime_config.json"))
            .expect("reopened runtime config");
    assert!(
        reopened_runtime.contains("\"hardfork\": true"),
        "runtime config not preserved across roundtrip:\n{}",
        reopened_runtime
    );

    // --- 8. Determinism: re-saving an unchanged session must be byte-identical
    let hf_deb_resave = tmp
        .path()
        .join("mina-hardfork-mainnet_4.0.0_amd64.resave.deb");
    run(bin, &["session", "save"], &[&reopened, &hf_deb_resave]);

    let first = std::fs::read(&hf_deb).unwrap();
    let second = std::fs::read(&hf_deb_resave).unwrap();
    assert_eq!(
        first.len(),
        second.len(),
        "resaved package differs in size — non-deterministic output"
    );
    assert_eq!(
        sha256(&first),
        sha256(&second),
        "resaved package has different bytes — non-deterministic output"
    );
}

fn sha256(bytes: &[u8]) -> String {
    use std::process::Stdio;
    let mut child = Command::new("sha256sum")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("sha256sum");
    use std::io::Write;
    child
        .stdin
        .as_mut()
        .unwrap()
        .write_all(bytes)
        .expect("write to sha256sum");
    let out = child.wait_with_output().expect("sha256sum output");
    String::from_utf8_lossy(&out.stdout)
        .split_whitespace()
        .next()
        .unwrap()
        .to_string()
}
