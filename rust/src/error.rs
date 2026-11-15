//! Error types for the rtemis-a3 library.
//!
//! All fallible operations return `Result<T, A3Error>`. The variants map onto
//! the three failure modes A3 distinguishes:
//!
//! - [`A3Error::Parse`]     — the input was not valid JSON
//! - [`A3Error::Validate`]  — the JSON parsed but violated A3 rules
//! - [`A3Error::Serialize`] — a valid A3 value could not be serialized
//!
//! A parse failure is deliberately *not* a validation issue: a file that is not
//! JSON has no path to report and nothing further to collect. Everything else
//! is collectable, which is why [`A3Error::Validate`] carries a list.

use thiserror::Error;

use crate::issue::A3Issue;

/// The single error type returned by every fallible function in this crate.
///
/// In Rust, errors are values — there are no exceptions. Every function that
/// can fail returns `Result<T, A3Error>`, which is either `Ok(value)` or
/// `Err(A3Error::...)`. The caller decides how to handle it.
#[derive(Debug, Error)]
pub enum A3Error {
    /// The input string is not valid JSON.
    ///
    /// `#[from]` implements `From<serde_json::Error> for A3Error` automatically,
    /// enabling the `?` operator to convert deserialization errors into this
    /// variant without an explicit `.map_err(...)` call.
    #[error("Failed to parse JSON: {0}")]
    Parse(#[from] serde_json::Error),

    /// A validated [`crate::A3`] could not be serialized to JSON.
    ///
    /// Unreachable for well-typed A3 values, but kept distinct from
    /// [`A3Error::Parse`] so that messages reflect the real failure mode.
    #[error("Failed to serialize to JSON: {0}")]
    Serialize(serde_json::Error),

    /// The input is structurally valid JSON but violates A3 rules.
    ///
    /// Carries every issue found in the earliest validation stage that produced
    /// one. See [`A3Issue`] and [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md).
    #[error("A3 validation failed with {} issue(s):\n{}", .0.len(), format_issues(.0))]
    Validate(Vec<A3Issue>),
}

impl A3Error {
    /// The validation issues carried by this error, or an empty slice for the
    /// parse and serialize variants.
    ///
    /// Lets a caller reach the issue list without matching on the variant:
    /// `for issue in err.issues() { ... }`.
    pub fn issues(&self) -> &[A3Issue] {
        match self {
            A3Error::Validate(issues) => issues,
            _ => &[],
        }
    }

    /// The validation stage the reported issues belong to, or `None` when this
    /// error carries no issues.
    ///
    /// Every issue in a `Validate` error comes from the same stage, because
    /// validation short-circuits at a stage boundary.
    pub fn stage(&self) -> Option<u8> {
        self.issues().first().map(A3Issue::stage)
    }
}

/// Render an issue list as one indented line each.
fn format_issues(issues: &[A3Issue]) -> String {
    issues
        .iter()
        .map(|i| format!("  {i}"))
        .collect::<Vec<_>>()
        .join("\n")
}
