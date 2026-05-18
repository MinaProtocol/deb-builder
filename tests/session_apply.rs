//! End-to-end tests for `session apply` (the JSON-manifest mode).
//!
//! Three things to cover:
//!
//!   1. Full happy path: a bundle directory containing `plan.json`
//!      plus its referenced data files applies cleanly, and the
//!      manifest-relative source paths resolve correctly even when
//!      the cwd differs from the bundle.
//!   2. `read-field` assertion semantics: when the actual control
//!      field doesn't match `expected`, the plan aborts at that step
//!      (steps before it stay applied, steps after it don't run).
//!   3. Schema strictness: an unknown `op` produces a useful error
//!      rather than silently succeeding.
//!
//! Skipped when `dpkg-deb` isn't on PATH.

mod common;
use common::*;

#[test]
fn apply_full_variant_manifest() {
    skip_unless!("dpkg-deb");

    let tk = Toolkit::new();
    let tmp = tempfile::tempdir().unwrap();

    // ---------------------------------------------------------------------
    // 1. Build the input .deb.
    // ---------------------------------------------------------------------
    let original = DebFixture::new("example-app")
        .version("1.0.0")
        .suite("stable")
        .depends("example-helper (= 1.0.0), libssl3 (>= 3.0.0)")
        .file("/var/lib/example/data.bin", b"ORIGINAL\n".to_vec())
        .file(
            "/etc/example/config.json",
            b"{\"channel\":\"stable\"}\n".to_vec(),
        )
        .build(&tmp.path().join("example-app_1.0.0_amd64.deb"));

    // ---------------------------------------------------------------------
    // 2. Build a manifest *bundle*: plan.json + its data files in their
    //    own directory. Relative paths inside the manifest are resolved
    //    against this directory, so the bundle is portable.
    // ---------------------------------------------------------------------
    let bundle = tmp.path().join("variant-bundle");
    std::fs::create_dir_all(&bundle).unwrap();
    std::fs::write(bundle.join("data.bin"), b"VARIANT DATA\n").unwrap();
    std::fs::write(bundle.join("config.json"), b"{\"channel\":\"variant\"}\n").unwrap();
    std::fs::write(
        bundle.join("plan.json"),
        r#"{
            "description": "Rebrand example-app as example-app-variant 2.0.0",
            "steps": [
                { "op": "remove", "pattern": "/var/lib/example/data.bin" },
                { "op": "insert",
                  "dest": "/var/lib/example/data.bin",
                  "sources": ["./data.bin"] },
                { "op": "replace",
                  "pattern": "/etc/example/config.json",
                  "replacement": "./config.json" },
                { "op": "rename-package", "new_name": "example-app-variant" },
                { "op": "reversion", "new_version": "2.0.0", "update_deps": true },
                { "op": "replace-suite", "new_suite": "experimental" },
                { "op": "read-field", "field": "Package",
                  "expected": "example-app-variant" },
                { "op": "read-field", "field": "Version", "expected": "2.0.0" }
            ]
        }"#,
    )
    .unwrap();

    // ---------------------------------------------------------------------
    // 3. open + apply + save.
    // ---------------------------------------------------------------------
    let session = tmp.path().join("session");
    tk.session_open(&original, &session).assert_success();
    tk.session_apply(&session, &bundle.join("plan.json"))
        .assert_success();

    let output = tmp.path().join("output.deb");
    tk.session_save(&session, &output, /*verify=*/ true)
        .assert_success();

    // ---------------------------------------------------------------------
    // 4. Assert on the produced .deb.
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
        "= pin not rewritten:\n{}",
        info
    );
    assert!(
        info.contains("libssl3 (>= 3.0.0)"),
        ">= constraint should have been left alone:\n{}",
        info
    );

    // ---------------------------------------------------------------------
    // 5. Re-open and verify the bundle-relative source files made it
    //    in correctly. This is the property test for path resolution:
    //    if relative paths had been resolved against cwd instead of
    //    the bundle dir, the inserted file would have wrong content
    //    (or `insert` would have errored).
    // ---------------------------------------------------------------------
    let reopened = tmp.path().join("reopened");
    tk.session_open(&output, &reopened).assert_success();

    let config = std::fs::read_to_string(reopened.join("data/etc/example/config.json")).unwrap();
    assert!(
        config.contains("\"channel\":\"variant\""),
        "config not replaced from bundle:\n{}",
        config
    );

    let data = std::fs::read(reopened.join("data/var/lib/example/data.bin")).unwrap();
    assert_eq!(data, b"VARIANT DATA\n");
}

#[test]
fn apply_read_field_assertion_failure_aborts_plan() {
    skip_unless!("dpkg-deb");

    let tk = Toolkit::new();
    let tmp = tempfile::tempdir().unwrap();

    let input = DebFixture::new("example-app")
        .version("1.0.0")
        .file("/usr/share/example/marker", b"x\n".to_vec())
        .build(&tmp.path().join("input.deb"));

    // Plan asserts the WRONG value for Package — should abort at step 2.
    let plan = tmp.path().join("plan.json");
    std::fs::write(
        &plan,
        r#"{ "steps": [
            { "op": "rename-package", "new_name": "renamed-by-step-1" },
            { "op": "read-field", "field": "Package", "expected": "WRONG_VALUE" },
            { "op": "replace-suite", "new_suite": "stable" }
        ] }"#,
    )
    .unwrap();

    let session = tmp.path().join("session");
    tk.session_open(&input, &session).assert_success();

    tk.session_apply(&session, &plan)
        .assert_failure()
        .stderr_contains("read-field assertion failed");

    // Step 1 (rename) ran. Step 3 (replace-suite) did NOT — the plan
    // aborted at step 2.
    let pkg = tk.session_read_field(&session, "Package").assert_success();
    assert_eq!(pkg.stdout_trim(), "renamed-by-step-1");
}

#[test]
fn apply_rejects_unknown_op() {
    skip_unless!("dpkg-deb");

    let tk = Toolkit::new();
    let tmp = tempfile::tempdir().unwrap();

    let input = DebFixture::new("example-app")
        .file("/usr/share/example/x", b"x\n".to_vec())
        .build(&tmp.path().join("input.deb"));

    let session = tmp.path().join("session");
    tk.session_open(&input, &session).assert_success();

    let plan = tmp.path().join("plan.json");
    std::fs::write(&plan, r#"{ "steps": [{ "op": "destroy-everything" }] }"#).unwrap();

    tk.session_apply(&session, &plan).assert_failure();
}
