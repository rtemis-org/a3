//! `a3` — CLI tool to validate and inspect A3 amino acid annotation files.
//!
//! Usage: `a3 [OPTIONS] <FILE>`
//! Pass `-` as `<FILE>` to read from stdin.

mod diagnostic;

use clap::Parser;
use colored::Colorize;
use rtemis_a3::{A3, A3_SCHEMA_URI, A3_VERSION, A3Error, validate};
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

    /// Run full diagnostic validation (accumulates all errors)
    #[arg(short = 'D', long)]
    diagnose: bool,
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
    if lines.is_empty() {
        vec![text.to_string()]
    } else {
        lines
    }
}

/// Build the parenthetical name hint for an annotation row.
///
/// Shows up to 3 names. Appends `…` if there are more than 3 total, or if
/// any name had to be cropped to stay within `available` display columns.
/// `available` is the space for the content *inside* the parentheses.
fn build_hint(names: &[String], available: usize) -> String {
    if names.is_empty() || available < 2 {
        return String::new();
    }
    let more_than_three = names.len() > 3;
    let mut result = String::new();

    for (i, name) in names.iter().take(3).enumerate() {
        let sep = if i == 0 { "" } else { ", " };
        let candidate = format!("{}{}", sep, name);
        let after_cols = result.chars().count() + candidate.chars().count();
        // Reserve 1 display column for "…" unless this is provably the last item.
        let is_last = i + 1 == names.len() && !more_than_three;
        let reserve = if is_last { 0 } else { 1 };

        if after_cols + reserve <= available {
            result.push_str(&candidate);
        } else {
            // Crop: append "…" to whatever we've accumulated so far.
            if result.chars().count() < available {
                result.push('…');
            }
            return result;
        }
    }

    if more_than_three && result.chars().count() < available {
        result.push('…');
    }
    result
}

/// Print human-readable output.
///
/// `errors` is empty when the file is valid, non-empty when validation failed.
/// In both cases we print whatever metadata and stats are available.
fn print_human(a3: &A3, errors: &[String], limit: usize) {
    println!();
    // --- Status line ---
    if errors.is_empty() {
        println!(
            "  {} {} {}",
            "✓ valid".green().bold(),
            format!("{{A3 {}}}", a3.a3_version())
                .bold()
                .truecolor(71, 156, 255),
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
    println!(
        "  {}  {}",
        "Sequence".bold(),
        seq_display.truecolor(220, 150, 86)
    );

    // --- Annotations ---
    println!();
    println!("  {}", "Annotations".bold());

    let ann = a3.annotations();

    // Sorted names per family (all of them — build_hint decides how many fit).
    // Variant has no names; show positions instead.
    let mut site_names: Vec<String> = ann.site().keys().cloned().collect();
    site_names.sort();
    let mut region_names: Vec<String> = ann.region().keys().cloned().collect();
    region_names.sort();
    let mut ptm_names: Vec<String> = ann.ptm().keys().cloned().collect();
    ptm_names.sort();
    let mut proc_names: Vec<String> = ann.processing().keys().cloned().collect();
    proc_names.sort();
    let var_names: Vec<String> = ann
        .variant()
        .iter()
        .map(|v| format!("pos {}", v.position()))
        .collect();

    let entries = [
        ("site", ann.site().len(), site_names),
        ("region", ann.region().len(), region_names),
        ("ptm", ann.ptm().len(), ptm_names),
        ("processing", ann.processing().len(), proc_names),
        ("variant", ann.variant().len(), var_names),
    ];
    let last = entries.len() - 1;
    for (i, (name, count, names)) in entries.iter().enumerate() {
        let connector = if i == last { "└──" } else { "├──" };
        let padded = format!("{:<12}", name).dimmed();
        let count_str = if *count == 0 {
            "—".dimmed().to_string()
        } else {
            count.to_string().truecolor(220, 150, 86).to_string()
        };
        // Columns consumed before the opening paren:
        // 2 (indent) + 3 (connector) + 1 (space) + 12 (padded name) + count digits + 2 (gap) + 1 '('
        let prefix_cols = 21
            + if *count == 0 {
                1
            } else {
                count.to_string().len()
            };
        let available = 90usize.saturating_sub(prefix_cols + 1); // +1 for ')'
        let hint_content = build_hint(names, available);
        let hint = if hint_content.is_empty() {
            String::new()
        } else {
            format!("  {}", format!("({})", hint_content).dimmed())
        };
        println!("  {} {}{}{}", connector.dimmed(), padded, count_str, hint);
    }

    // --- Metadata ---
    println!();
    println!("  {}", "Metadata".bold());

    let meta = a3.metadata();
    // Only include fields that have a value.
    let meta_rows: Vec<(&str, &str)> = [
        ("UniProt ID", meta.uniprot_id()),
        ("Description", meta.description()),
        ("Reference", meta.reference()),
        ("Organism", meta.organism()),
    ]
    .into_iter()
    .filter(|(_, v)| !v.is_empty())
    .collect();

    if meta_rows.is_empty() {
        println!("  {}", "(empty)".dimmed());
    } else {
        let label_width = meta_rows.iter().map(|(l, _)| l.len()).max().unwrap_or(0);
        // 2 (indent) + 3 (connector) + 1 (space) + label_width + 2 (gap)
        let value_col = 8 + label_width;
        let value_width = 90usize.saturating_sub(value_col);
        let last = meta_rows.len() - 1;
        for (i, (label, value)) in meta_rows.iter().enumerate() {
            let is_last = i == last;
            let connector = if is_last { "└──" } else { "├──" };
            // Non-last items get a │ at the connector column to keep the list
            // visually uninterrupted across wrapped value lines.
            let continuation = if is_last {
                " ".repeat(value_col)
            } else {
                format!("  {}{}", "│".dimmed(), " ".repeat(value_col - 3))
            };
            let lines = wrap_words(value, value_width);
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

    // --diagnose: full step-by-step validation that accumulates all errors.
    if cli.diagnose {
        match diagnostic::a3_diagnose(&content) {
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
            Err(errors) => {
                if !cli.quiet {
                    if cli.json {
                        println!(
                            "{}",
                            serde_json::to_string_pretty(&json!({
                                "valid": false,
                                "errors": errors,
                            }))
                            .unwrap()
                        );
                    } else {
                        println!("\n  {}", "✗ invalid".red().bold());
                        println!();
                        let last = errors.len() - 1;
                        for (i, msg) in errors.iter().enumerate() {
                            let connector = if i == last { "└──" } else { "├──" };
                            println!("  {} {}", connector.dimmed(), msg.red());
                        }
                        println!();
                    }
                }
                process::exit(1);
            }
        }
    }

    // Stage 1: JSON parse — exit 2 on failure.
    let raw: A3 = match serde_json::from_str(&content) {
        Ok(r) => r,
        Err(e) => {
            if !cli.quiet {
                let mut errors = vec![format!("Failed to parse JSON: {e}")];

                // Even though full deserialization failed, try parsing to a
                // generic Value so we can check envelope fields and surface
                // *all* errors at once instead of just the first serde failure.
                if let Ok(value) = serde_json::from_str::<serde_json::Value>(&content) {
                    match value.get("$schema").and_then(|v| v.as_str()) {
                        Some(s) if s != A3_SCHEMA_URI => {
                            errors.push(format!("'$schema' must be '{A3_SCHEMA_URI}', got '{s}'"));
                        }
                        None => {
                            errors.push(format!(
                                "'$schema' is required and must be '{A3_SCHEMA_URI}'"
                            ));
                        }
                        _ => {}
                    }
                    match value.get("a3_version").and_then(|v| v.as_str()) {
                        Some(v) if v != A3_VERSION => {
                            errors.push(format!("'a3_version' must be '{A3_VERSION}', got '{v}'"));
                        }
                        None => {
                            errors.push(format!(
                                "'a3_version' is required and must be '{A3_VERSION}'"
                            ));
                        }
                        _ => {}
                    }
                }

                if cli.json {
                    println!(
                        "{}",
                        serde_json::to_string_pretty(&json!({
                            "valid": false,
                            "errors": errors,
                        }))
                        .unwrap()
                    );
                } else {
                    println!("\n  {}", "✗ invalid".red().bold());
                    println!();
                    let last = errors.len() - 1;
                    for (i, msg) in errors.iter().enumerate() {
                        let connector = if i == last { "└──" } else { "├──" };
                        println!("  {} {}", connector.dimmed(), msg.red());
                    }
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
