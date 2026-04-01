//! `a3` — CLI tool to validate and inspect A3 amino acid annotation files.
//!
//! Usage: `a3 [OPTIONS] <FILE>`
//! Pass `-` as `<FILE>` to read from stdin.

use clap::Parser;
use rtemis_a3::{A3, A3Error, validate};
use serde_json::{Value, json};
use std::io::{self, Read};
use std::process;

// ---------------------------------------------------------------------------
// CLI definition
// ---------------------------------------------------------------------------

#[derive(Parser)]
#[command(
    name = "a3",
    version,
    about = "Validate and inspect A3 amino acid annotation files"
)]
struct Cli {
    /// Path to the A3 JSON file (use `-` for stdin)
    file: String,

    /// Maximum number of sequence residues to display
    #[arg(short, long, default_value_t = 10)]
    limit: usize,

    /// Suppress all output; use exit code only
    #[arg(short, long)]
    quiet: bool,

    /// Output results in JSON format
    #[arg(short, long)]
    json: bool,
}

// ---------------------------------------------------------------------------
// Output helpers
// ---------------------------------------------------------------------------

/// Print human-readable output.
///
/// `errors` is empty when the file is valid, non-empty when validation failed.
/// In both cases we print whatever metadata and stats are available.
fn print_human(a3: &A3, errors: &[String], limit: usize) {
    if errors.is_empty() {
        println!("✓ valid A3 schema version 1.0.0 (https://schema.rtemis.org/a3/v1/schema.json)");
    } else {
        println!("✗ invalid:");
        for e in errors {
            println!("  - {e}");
        }
    }

    let meta = a3.metadata();
    let ann = a3.annotations();
    let seq = a3.sequence();
    let n = limit.min(seq.len());
    let seq_line = if seq.len() > n {
        format!("{}... ({})", &seq[..n], seq.len())
    } else {
        format!("{} ({})", seq, seq.len())
    };

    println!("UniProt ID:   {}", meta.uniprot_id());
    println!("Description:  {}", meta.description());
    println!("Reference:    {}", meta.reference());
    println!("Organism:     {}", meta.organism());
    println!("Sequence:     {}", seq_line);
    println!(
        "Annotations:  site: {}  region: {}  ptm: {}  processing: {}  variant: {}",
        ann.site().len(),
        ann.region().len(),
        ann.ptm().len(),
        ann.processing().len(),
        ann.variant().len(),
    );
}

/// Build the JSON output value.
///
/// Same signature as `print_human` — `errors` empty means valid.
fn build_json(a3: &A3, errors: &[String], limit: usize) -> Value {
    let meta = a3.metadata();
    let ann = a3.annotations();
    let seq = a3.sequence();
    let n = limit.min(seq.len());

    json!({
        "valid": errors.is_empty(),
        "errors": errors,
        "metadata": {
            "uniprot_id": meta.uniprot_id(),
            "description": meta.description(),
            "reference": meta.reference(),
            "organism": meta.organism(),
        },
        "sequence_length": seq.len(),
        "sequence_preview": &seq[..n],
        "annotations": {
            "site": ann.site().len(),
            "region": ann.region().len(),
            "ptm": ann.ptm().len(),
            "processing": ann.processing().len(),
            "variant": ann.variant().len(),
        }
    })
}

// ---------------------------------------------------------------------------
// Input reading
// ---------------------------------------------------------------------------

fn read_input(file: &str) -> Result<String, String> {
    if file == "-" {
        let mut buf = String::new();
        io::stdin()
            .read_to_string(&mut buf)
            .map_err(|e| format!("Error reading stdin: {e}"))?;
        Ok(buf)
    } else {
        std::fs::read_to_string(file).map_err(|e| format!("Error reading '{file}': {e}"))
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    let cli = Cli::parse();

    // Read input — exit 2 on I/O error.
    let content = read_input(&cli.file).unwrap_or_else(|e| {
        if !cli.quiet {
            eprintln!("{e}");
        }
        process::exit(2);
    });

    // Stage 1: JSON parse — exit 2 on failure.
    let raw: A3 = match serde_json::from_str(&content) {
        Ok(r) => r,
        Err(e) => {
            if !cli.quiet {
                let msg = format!("Failed to parse JSON: {e}");
                if cli.json {
                    println!(
                        "{}",
                        serde_json::to_string_pretty(&json!({
                            "valid": false,
                            "errors": [msg],
                        }))
                        .unwrap()
                    );
                } else {
                    println!("✗ invalid:");
                    println!("  - {msg}");
                }
            }
            process::exit(2);
        }
    };

    // Snapshot raw data before validate() moves `raw`.
    // Needed so we can still report metadata when validation fails.
    let raw_snapshot = raw.clone();

    // Stage 2: A3 validation.
    match validate(raw) {
        Ok(a3) => {
            if !cli.quiet {
                if cli.json {
                    println!(
                        "{}",
                        serde_json::to_string_pretty(&build_json(&a3, &[], cli.limit)).unwrap()
                    );
                } else {
                    print_human(&a3, &[], cli.limit);
                }
            }
            process::exit(0);
        }
        Err(A3Error::Validate(errors)) => {
            if !cli.quiet {
                if cli.json {
                    println!(
                        "{}",
                        serde_json::to_string_pretty(&build_json(
                            &raw_snapshot,
                            &errors,
                            cli.limit,
                        ))
                        .unwrap()
                    );
                } else {
                    print_human(&raw_snapshot, &errors, cli.limit);
                }
            }
            process::exit(1);
        }
        // validate() only ever returns Validate errors; this branch is unreachable
        // in practice but required for exhaustive matching.
        Err(e) => {
            if !cli.quiet {
                eprintln!("Unexpected error: {e}");
            }
            process::exit(2);
        }
    }
}
