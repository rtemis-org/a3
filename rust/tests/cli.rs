use std::io::Write;
use std::process::{Command, Stdio};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn a3() -> Command {
    Command::new(env!("CARGO_BIN_EXE_a3"))
}

/// Spawn `a3` with `args`, write `stdin_data` to its stdin, and return the
/// full output (stdout + stderr + exit status).
fn run(args: &[&str], stdin_data: &str) -> std::process::Output {
    let mut child = a3()
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("failed to spawn a3 binary");

    child
        .stdin
        .take()
        .unwrap()
        .write_all(stdin_data.as_bytes())
        .unwrap();

    child.wait_with_output().expect("failed to wait for a3")
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const VALID_JSON: &str = r#"{"$schema":"https://schema.rtemis.org/a3/v1/schema.json","a3_version":"1.0.0","sequence":"MAEPRQ","annotations":{"site":{},"region":{},"ptm":{},"processing":{},"variant":[]},"metadata":{"uniprot_id":"P12345","description":"Test protein","reference":"","organism":"Homo sapiens"}}"#;

/// Valid JSON whose site annotation has a position beyond the sequence length.
const INVALID_A3_JSON: &str = r#"{"$schema":"https://schema.rtemis.org/a3/v1/schema.json","a3_version":"1.0.0","sequence":"MAEPRQ","annotations":{"site":{"bad":{"index":[999],"type":""}},"region":{},"ptm":{},"processing":{},"variant":[]},"metadata":{"uniprot_id":"","description":"","reference":"","organism":""}}"#;

/// Not valid JSON at all.
const BAD_JSON: &str = r#"{not valid json"#;

/// Invalid A3 whose sequence contains non-ASCII (multibyte) characters.
/// --limit 1 would previously land mid-codepoint and panic.
const NON_ASCII_JSON: &str = r#"{"$schema":"https://schema.rtemis.org/a3/v1/schema.json","a3_version":"1.0.0","sequence":"éàü","annotations":{"site":{},"region":{},"ptm":{},"processing":{},"variant":[]},"metadata":{"uniprot_id":"","description":"","reference":"","organism":""}}"#;

// ---------------------------------------------------------------------------
// Exit code tests
// ---------------------------------------------------------------------------

#[test]
fn valid_input_exits_0() {
    let out = run(&["-"], VALID_JSON);
    assert_eq!(out.status.code(), Some(0));
}

#[test]
fn invalid_a3_exits_1() {
    let out = run(&["-"], INVALID_A3_JSON);
    assert_eq!(out.status.code(), Some(1));
}

#[test]
fn bad_json_exits_2() {
    let out = run(&["-"], BAD_JSON);
    assert_eq!(out.status.code(), Some(2));
}

#[test]
fn missing_file_exits_2() {
    let out = a3().arg("/nonexistent/path/to/file.json").output().unwrap();
    assert_eq!(out.status.code(), Some(2));
}

// ---------------------------------------------------------------------------
// JSON output shape tests
// ---------------------------------------------------------------------------

#[test]
fn json_output_valid() {
    let out = run(&["--json", "-"], VALID_JSON);
    assert_eq!(out.status.code(), Some(0));

    let v: serde_json::Value =
        serde_json::from_slice(&out.stdout).expect("stdout was not valid JSON");

    assert_eq!(v["valid"], true);
    assert!(v["errors"].as_array().unwrap().is_empty());
    assert_eq!(v["sequence_length"], 6);
    assert_eq!(v["metadata"]["uniprot_id"], "P12345");
}

#[test]
fn json_output_invalid_a3() {
    let out = run(&["--json", "-"], INVALID_A3_JSON);
    assert_eq!(out.status.code(), Some(1));

    let v: serde_json::Value =
        serde_json::from_slice(&out.stdout).expect("stdout was not valid JSON");

    assert_eq!(v["valid"], false);
    assert!(!v["errors"].as_array().unwrap().is_empty());
}

#[test]
fn json_output_bad_json() {
    let out = run(&["--json", "-"], BAD_JSON);
    assert_eq!(out.status.code(), Some(2));

    let v: serde_json::Value =
        serde_json::from_slice(&out.stdout).expect("stdout was not valid JSON");

    assert_eq!(v["valid"], false);
    assert!(!v["errors"].as_array().unwrap().is_empty());
}

// ---------------------------------------------------------------------------
// Quiet flag
// ---------------------------------------------------------------------------

#[test]
fn quiet_suppresses_stdout() {
    let out = run(&["--quiet", "-"], VALID_JSON);
    assert_eq!(out.status.code(), Some(0));
    assert!(out.stdout.is_empty());
}

// ---------------------------------------------------------------------------
// Regression: non-ASCII sequence with small --limit must not panic
// ---------------------------------------------------------------------------

#[test]
fn non_ascii_sequence_with_limit_1_does_not_panic() {
    // This would panic before the fix if --limit landed mid-codepoint.
    let out = run(&["--limit", "1", "-"], NON_ASCII_JSON);
    // Exits 1 (invalid sequence chars), but must not crash.
    assert_ne!(
        out.status.code(),
        None,
        "process was killed by a signal (panic)"
    );
    assert_ne!(out.status.code(), Some(101), "process panicked");
}

#[test]
fn non_ascii_sequence_json_output_does_not_panic() {
    let out = run(&["--json", "--limit", "1", "-"], NON_ASCII_JSON);
    assert_ne!(out.status.code(), None);
    assert_ne!(out.status.code(), Some(101));
    // Output must still be parseable JSON.
    let _: serde_json::Value =
        serde_json::from_slice(&out.stdout).expect("stdout was not valid JSON");
}
