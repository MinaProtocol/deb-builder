use anyhow::{anyhow, Result};
use regex::Regex;
use std::process::Command;

use crate::misc::{check_command_exists, check_file_exists};

/// Extract the signing-key id from a .deb by invoking debsig-verify with a
/// deliberately-fake policies directory and parsing the resulting error.
///
/// debsig-verify prints lines like:
///   debsig: Origin Signature check failed.  This deb might not be signed,
///   ...
///   fake/<KEY_ID>: ...
/// — the path `fake/<KEY_ID>` is what we grep for.
pub fn signature(deb: &str, debug: bool) -> Result<String> {
    check_command_exists("debsig-verify")?;
    check_file_exists(deb)?;

    if debug {
        log::info!("Executing: debsig-verify --policies-dir fake {}", deb);
    }

    let output = Command::new("debsig-verify")
        .args(["--policies-dir", "fake", deb])
        .output()
        .map_err(|e| anyhow!("Failed to spawn debsig-verify: {}", e))?;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let msg = format!(
            "Cannot look up package signature due to internal error. Expecting \
             command to error out\n {}",
            stdout
        );
        log::error!("{}", msg);
        return Err(anyhow!(msg));
    }

    // Newer versions of debsig-verify route the diagnostic containing
    // the `fake/<KEY_ID>` path to stderr; older versions printed it to
    // stdout. Search both streams so the parse stays working across
    // distro versions.
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let re = Regex::new(r"fake/([A-Fa-f0-9]+)[:/]").unwrap();
    if let Some(caps) = re.captures(&stdout).or_else(|| re.captures(&stderr)) {
        return Ok(caps.get(1).unwrap().as_str().to_uppercase());
    }
    Err(anyhow!(
        "Failed to extract key id from debsig-verify output.\n\
         stdout: {}\n\
         stderr: {}",
        stdout.trim(),
        stderr.trim()
    ))
}
