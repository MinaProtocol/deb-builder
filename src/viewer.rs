use anyhow::{anyhow, Context, Result};
use regex::Regex;
use std::io::{Read, Write};
use std::process::{Command, Stdio};

use crate::misc::{check_command_exists, check_file_exists};

/// Extract the signing-key id from a .deb.
///
/// A `.deb` is an `ar` archive; `debsigs --sign=origin` (the signing
/// path we use) embeds the GPG signature as a member called
/// `_gpgorigin`. We pull that member out directly and ask `gpg
/// --list-packets` for the issuer key id. This is more robust than
/// scraping debsig-verify's error output — that approach depended on
/// the exact wording of a diagnostic line which has changed between
/// Debian versions (see git history for the previous, fragile
/// implementation).
pub fn signature(deb: &str, debug: bool) -> Result<String> {
    check_command_exists("gpg")?;
    check_file_exists(deb)?;
    if debug {
        log::info!("Extracting signature blob from {}", deb);
    }

    let sig_bytes = extract_signature_member(deb)?;
    parse_keyid_with_gpg(&sig_bytes, debug)
}

/// Pull the GPG-signature ar member out of `deb`. Recognized member
/// names are `_gpgorigin` (debsigs origin role, what we sign with)
/// and `_gpgbuilder` (alternate role debsigs supports).
fn extract_signature_member(deb: &str) -> Result<Vec<u8>> {
    let f = std::fs::File::open(deb).with_context(|| format!("Opening {} as ar archive", deb))?;
    let mut archive = ar::Archive::new(f);
    while let Some(entry) = archive.next_entry() {
        let mut entry = entry.with_context(|| format!("Reading ar entry from {}", deb))?;
        let name = std::str::from_utf8(entry.header().identifier())
            .unwrap_or("")
            .trim_end_matches('/')
            .to_string();
        if name == "_gpgorigin" || name == "_gpgbuilder" {
            let mut buf = Vec::with_capacity(entry.header().size() as usize);
            entry.read_to_end(&mut buf)?;
            return Ok(buf);
        }
    }
    Err(anyhow!(
        "No `_gpgorigin`/`_gpgbuilder` member in {} — package is not signed",
        deb
    ))
}

/// Pipe the raw signature into `gpg --list-packets` and parse the
/// `keyid <HEX>` line.
fn parse_keyid_with_gpg(sig: &[u8], debug: bool) -> Result<String> {
    let mut child = Command::new("gpg")
        .args(["--list-packets"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| anyhow!("Failed to spawn gpg: {}", e))?;
    child
        .stdin
        .as_mut()
        .ok_or_else(|| anyhow!("Failed to open gpg stdin"))?
        .write_all(sig)?;
    let out = child.wait_with_output()?;
    let stdout = String::from_utf8_lossy(&out.stdout);
    let stderr = String::from_utf8_lossy(&out.stderr);
    if debug {
        log::info!("gpg --list-packets stdout:\n{}", stdout);
        log::info!("gpg --list-packets stderr:\n{}", stderr);
    }

    // gpg --list-packets prints (among other lines):
    //     :signature packet: algo 1, keyid 40C7DD112EDB4CA9
    // Match the keyid token; uppercase the captured value so the
    // returned id is always canonical.
    let re = Regex::new(r"keyid ([0-9A-Fa-f]+)").unwrap();
    if let Some(caps) = re.captures(&stdout) {
        return Ok(caps.get(1).unwrap().as_str().to_uppercase());
    }
    Err(anyhow!(
        "Failed to extract key id from gpg --list-packets output.\n\
         stdout: {}\n\
         stderr: {}",
        stdout.trim(),
        stderr.trim()
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_keyid_from_gpg_output() {
        // Synthetic capture-only test against the regex.
        let sample = "\
:signature packet: algo 1, keyid 40C7DD112EDB4CA9
        version 4, created 1717..., md5len 0, sigclass 0x00
        digest algo 8, begin of digest aa bb
";
        let re = Regex::new(r"keyid ([0-9A-Fa-f]+)").unwrap();
        let caps = re.captures(sample).expect("regex should match");
        assert_eq!(caps.get(1).unwrap().as_str(), "40C7DD112EDB4CA9");
    }
}
