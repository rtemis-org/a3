//! Error types for the rtemis-a3 library.
//!
//! All fallible operations return `Result<T, A3Error>`. The two variants
//! map onto the two failure modes described in the A3 spec:
//!
//! - [`A3Error::Parse`]    — the input was not valid JSON
//! - [`A3Error::Validate`] — the JSON parsed but violated A3 rules

// `thiserror::Error` is a derive macro that generates the boilerplate needed
// to make our enum implement the standard `std::error::Error` trait.
use thiserror::Error;

/// The single error type returned by every fallible function in this crate.
///
/// In Rust, errors are values — there are no exceptions. Every function that
/// can fail returns `Result<T, A3Error>`, which is either `Ok(value)` or
/// `Err(A3Error::...)`. The caller decides how to handle it.
///
/// `#[derive(Debug)]` lets you print the error with `{:?}` formatting.
/// `#[derive(Error)]` (from thiserror) implements `std::error::Error` for us.
#[derive(Debug, Error)]
pub enum A3Error {
    /// Returned when the input string is not valid JSON.
    ///
    /// `#[error("...")]` defines the human-readable message produced by
    /// `.to_string()` or the `{}` format specifier.
    ///
    /// `{0}` refers to the first (and only) field of this variant by position.
    /// `serde_json::Error` is the underlying parse error from the JSON library.
    ///
    /// `#[from]` implements `From<serde_json::Error> for A3Error` automatically,
    /// enabling the `?` operator to convert deserialization errors into this
    /// variant without an explicit `.map_err(...)` call.
    #[error("Failed to parse JSON: {0}")]
    Parse(#[from] serde_json::Error),

    /// Returned when a validated [`crate::A3`] cannot be serialized to JSON.
    ///
    /// In practice this variant is unreachable for well-typed A3 values, but
    /// it is kept distinct from [`A3Error::Parse`] so that error messages
    /// accurately reflect the failure mode — serialization, not parsing.
    #[error("Failed to serialize to JSON: {0}")]
    Serialize(serde_json::Error),

    /// Returned when input is structurally valid JSON but violates A3 rules.
    ///
    /// We collect *all* validation errors into a `Vec<String>` so that a
    /// caller sees every problem at once, not just the first one encountered.
    ///
    /// `{0:#?}` uses the "alternate" debug formatter, which prints each
    /// element on its own line — readable for a list of error messages.
    #[error("A3 validation failed:\n{0:#?}")]
    Validate(Vec<String>),
}
