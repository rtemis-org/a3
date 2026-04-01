//! `a3` — CLI tool to validate and inspect A3 amino acid annotation files.
//!
//! Usage: `a3 [OPTIONS] <FILE>`
//! Pass `-` as `<FILE>` to read from stdin.

use clap::Parser;
use colored::Colorize;
use rtemis_a3::{A3, A3Error, validate};
use serde_json::{Value, json};
use std::io::{self, IsTerminal, Read};
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
    #[arg(short, long, default_value_t = 20)]
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

/// Word-wrap `text` to `width` columns, returning one string per line.
///
/// Words that individually exceed `width` are placed on their own line
/// unbroken. If `text` fits within `width`, returns a single-element vec.
fn wrap_words(text: &str, width: usize) -> Vec<String> {
    if width == 0 || text.len() <= width {
        return vec![text.to_string()];
    }
    let mut lines: Vec<String> = Vec::new();
    let mut current = String::new();
    for word in text.split_whitespace() {
        if current.is_empty() {
            current.push_str(word);
        } else if current.len() + 1 + word.len() <= width {
            current.push(' ');
            current.push_str(word);
        } else {
            lines.push(current.clone());
            current = word.to_string();
        }
    }
    if !current.is_empty() {
        lines.push(current);
    }
    if lines.is_empty() { vec![text.to_string()] } else { lines }
}

/// Return `s` if non-empty, otherwise a dimmed em-dash placeholder.
fn display_or_dash(s: &str) -> String {
    if s.is_empty() {
        "—".dimmed().to_string()
    } else {
        s.to_string()
    }
}

/// Print human-readable output.
///
/// `errors` is empty when the file is valid, non-empty when validation failed.
/// In both cases we print whatever metadata and stats are available.
fn print_human(a3: &A3, errors: &[String], limit: usize) {
    // --- Status line ---
    if errors.is_empty() {
        println!(
            "  {}  {}  {}",
            "✓ valid".green().bold(),
            format!("A3 {}", a3.a3_version()).cyan(),
            a3.schema().dimmed(),
        );
    } else {
        println!("  {}", "✗ invalid".red().bold());
        println!();
        let last = errors.len() - 1;
        for (i, e) in errors.iter().enumerate() {
            let connector = if i == last { "└──" } else { "├──" };
            println!("  {} {}", connector.dimmed(), e.red());
        }
    }

    println!();

    // --- Sequence ---
    let seq = a3.sequence();
    let n = limit.min(seq.len());
    let seq_display = if seq.len() > n {
        format!("{}… (length = {})", &seq[..n], seq.len())
    } else {
        format!("{} (length = {})", seq, seq.len())
    };
    println!("  {}  {}", "Sequence".bold(), seq_display.truecolor(220, 150, 86));

    // --- Annotations ---
    println!();
    println!("  {}", "Annotations".bold());

    let ann = a3.annotations();
    let entries = [
        ("site",       ann.site().len()),
        ("region",     ann.region().len()),
        ("ptm",        ann.ptm().len()),
        ("processing", ann.processing().len()),
        ("variant",    ann.variant().len()),
    ];
    let last = entries.len() - 1;
    for (i, (name, count)) in entries.iter().enumerate() {
        let connector = if i == last { "└──" } else { "├──" };
        let padded = format!("{:<12}", name).dimmed();
        let count_str = count.to_string().truecolor(220, 150, 86);
        println!("  {} {}{}", connector.dimmed(), padded, count_str);
    }

    // --- Metadata ---
    println!();
    println!("  {}", "Metadata".bold());

    let meta = a3.metadata();
    let meta_rows = [
        ("UniProt ID",  display_or_dash(meta.uniprot_id())),
        ("Description", display_or_dash(meta.description())),
        ("Reference",   display_or_dash(meta.reference())),
        ("Organism",    display_or_dash(meta.organism())),
    ];
    let label_width = meta_rows.iter().map(|(l, _)| l.len()).max().unwrap_or(0);
    // 2 (indent) + 3 (connector) + 1 (space) + label_width + 2 (gap)
    let value_col = 8 + label_width;
    let value_width = 90usize.saturating_sub(value_col);
    let continuation = " ".repeat(value_col);
    let last = meta_rows.len() - 1;
    for (i, (label, value)) in meta_rows.iter().enumerate() {
        let connector = if i == last { "└──" } else { "├──" };
        let lines = wrap_words(&value, value_width);
        print!(
            "  {} {}  {}",
            connector.dimmed(),
            format!("{:<width$}", label, width = label_width).dimmed(),
            lines[0].truecolor(220, 150, 86),
        );
        for line in &lines[1..] {
            print!("\n{}{}", continuation, line.truecolor(220, 150, 86));
        }
        println!();
    }
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

    // Disable colors when stdout is not a terminal (pipe, redirect, --quiet).
    if !std::io::stdout().is_terminal() {
        colored::control::set_override(false);
    }

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
                    println!("{}", "✗ invalid".red().bold());
                    println!();
                    println!("  {} {}", "└──".dimmed(), msg.red());
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
