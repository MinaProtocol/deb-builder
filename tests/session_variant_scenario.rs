//! End-to-end test: rebrand a stable package as a variant.
//!
//! This is the kind of workflow a CI pipeline runs when it forks an
//! existing release into a sub-channel: change the package identity,
//! bump the version (and the version pins in dep fields), swap a data
//! file and a config file, flip the suite, and ship.
//!
//! The scenario is deliberately project-agnostic. It uses the verbs in
//! a realistic combination rather than one-at-a-time, which is what the
//! verb-by-verb `session_roundtrip` test already covers.
//!
//! In addition to the rebrand itself, this test pins down two
//! properties the verb-by-verb test doesn't:
//!
//!   * **Field roundtrip survival.** Re-opens the produced .deb and
//!     reads the mutated fields + payload back through `session` —
//!     proves the mutations survived a full open/save cycle.
//!   * **Deterministic output.** Saves the re-opened session a second
//!     time, asserts byte-identical output. Useful for the artifact
//!     cache in CI.
//!
//! Skipped when `dpkg-deb` isn't on PATH.

mod common;
use common::*;

#[test]
fn rebrand_package_as_variant() {
    skip_unless!("dpkg-deb");

    let tk = Toolkit::new();
    let tmp = tempfile::tempdir().unwrap();

    // ---------------------------------------------------------------------
    // 1. Build a stable `example-app` fixture with a mix of dep styles
    //    (= pin, >= constraint, bare).
    // ---------------------------------------------------------------------
    let original = DebFixture::new("example-app")
        .version("1.0.0")
        .suite("stable")
        .depends("example-helper (= 1.0.0), libssl3 (>= 3.0.0), libcommon")
        .file("/var/lib/example/data.bin", b"ORIGINAL DATA\n".to_vec())
        .file(
            "/etc/example/config.json",
            b"{\"channel\":\"stable\"}\n".to_vec(),
        )
        .file(
            "/usr/local/bin/example",
            b"#!/bin/sh\necho example\n".to_vec(),
        )
        .build(&tmp.path().join("example-app_1.0.0_amd64.deb"));

    // ---------------------------------------------------------------------
    // 2. Open it, run the rebrand: swap data/config, rename, reversion,
    //    flip suite.
    // ---------------------------------------------------------------------
    let session = tmp.path().join("session");
    tk.session_open(&original, &session).assert_success();

    let new_data = tmp.path().join("new_data.bin");
    let new_config = tmp.path().join("new_config.json");
    std::fs::write(&new_data, b"VARIANT DATA\n").unwrap();
    std::fs::write(&new_config, b"{\"channel\":\"variant\"}\n").unwrap();

    tk.session_remove(&session, "/var/lib/example/data.bin")
        .assert_success();
    tk.session_insert(&session, "/var/lib/example/data.bin", &[&new_data], false)
        .assert_success();
    tk.session_replace(&session, "/etc/example/config.json", &new_config)
        .assert_success();

    tk.session_rename_package(&session, "example-app-variant")
        .assert_success();
    tk.session_reversion(&session, "2.0.0", /*update_deps=*/ true)
        .assert_success();
    tk.session_replace_suite(&session, "experimental")
        .assert_success();

    // ---------------------------------------------------------------------
    // 3. Save with verification.
    // ---------------------------------------------------------------------
    let output = tmp.path().join("output.deb");
    tk.session_save(&session, &output, /*verify=*/ true)
        .assert_success();
    assert!(output.is_file());

    // ---------------------------------------------------------------------
    // 4. Assert on the produced .deb via dpkg-deb.
    // ---------------------------------------------------------------------
    let info = dpkg::info(&output);
    assert!(
        info.contains("Package: example-app-variant"),
        "Package not renamed:\n{}",
        info
    );
    assert!(info.contains("Version: 2.0.0"), "Version wrong:\n{}", info);
    assert!(
        info.contains("Suite: experimental"),
        "Suite wrong:\n{}",
        info
    );
    assert!(
        info.contains("example-helper (= 2.0.0)"),
        "= pin should be rewritten:\n{}",
        info
    );
    assert!(
        info.contains("libssl3 (>= 3.0.0)"),
        ">= constraint should have been left alone:\n{}",
        info
    );
    assert!(
        info.contains("libcommon"),
        "unversioned dep dropped:\n{}",
        info
    );

    let contents = dpkg::contents(&output);
    assert!(
        contents.contains("var/lib/example/data.bin"),
        "new data file missing:\n{}",
        contents
    );
    assert!(
        contents.contains("usr/local/bin/example"),
        "binary should have been preserved:\n{}",
        contents
    );

    // ---------------------------------------------------------------------
    // 5. Re-open and verify state survives the roundtrip.
    // ---------------------------------------------------------------------
    let reopened = tmp.path().join("reopened");
    tk.session_open(&output, &reopened).assert_success();

    let pkg = tk.session_read_field(&reopened, "Package").assert_success();
    assert_eq!(pkg.stdout_trim(), "example-app-variant");
    let ver = tk.session_read_field(&reopened, "Version").assert_success();
    assert_eq!(ver.stdout_trim(), "2.0.0");

    let reopened_data =
        std::fs::read(reopened.join("data/var/lib/example/data.bin")).expect("reopened data");
    assert_eq!(reopened_data, b"VARIANT DATA\n");

    let reopened_config = std::fs::read_to_string(reopened.join("data/etc/example/config.json"))
        .expect("reopened config");
    assert!(
        reopened_config.contains("\"channel\":\"variant\""),
        "config not preserved across roundtrip:\n{}",
        reopened_config
    );

    // ---------------------------------------------------------------------
    // 6. Determinism: re-saving the unchanged session is byte-identical.
    // ---------------------------------------------------------------------
    let resave = tmp.path().join("resave.deb");
    tk.session_save(&reopened, &resave, /*verify=*/ false)
        .assert_success();

    let first = std::fs::read(&output).unwrap();
    let second = std::fs::read(&resave).unwrap();
    assert_eq!(
        first, second,
        "resaved package differs from original — non-deterministic output"
    );
}
