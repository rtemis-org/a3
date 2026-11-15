# Validation issues: stable codes, RFC 6901 paths, and human messages.
#
# The contract is defined in spec/error-codes.md and spec/error-paths.md at the
# repository root, and is shared by all five A3 implementations. An issue's
# `code` and `path` are contractual; its `message` is not and may be reworded
# freely.

"""
    A3_ISSUE_STAGES

Every A3 validation issue code, mapped to the validation stage it belongs to.

Codes are never renumbered and never reused. See
[`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) for the
full registry, including each code's trigger condition and the path it reports.
"""
const A3_ISSUE_STAGES = OrderedDict{String,Int}(
    # ── Stage 1 — Envelope ────────────────────────────────────────────────
    "A3E_DOC_NOT_OBJECT" => 1,
    "A3E_ENVELOPE_SCHEMA_MISSING" => 1,
    "A3E_ENVELOPE_SCHEMA_MISMATCH" => 1,
    "A3E_ENVELOPE_VERSION_MISSING" => 1,
    "A3E_ENVELOPE_VERSION_MISMATCH" => 1,

    # ── Stage 2 — Structural ──────────────────────────────────────────────
    "A3E_UNKNOWN_FIELD" => 2,
    "A3E_SEQ_MISSING" => 2,
    "A3E_SEQ_NOT_STRING" => 2,
    "A3E_SEQ_TOO_SHORT" => 2,
    "A3E_SEQ_CHARSET" => 2,
    "A3E_ANNOTATIONS_NOT_OBJECT" => 2,
    "A3E_METADATA_NOT_OBJECT" => 2,
    "A3E_METADATA_FIELD_NOT_STRING" => 2,
    "A3E_FAMILY_NOT_OBJECT" => 2,
    "A3E_VARIANT_LIST_NOT_ARRAY" => 2,
    "A3E_NAME_EMPTY" => 2,
    "A3E_ENTRY_NOT_OBJECT" => 2,
    "A3E_ENTRY_TYPE_NOT_STRING" => 2,
    "A3E_INDEX_MISSING" => 2,
    "A3E_INDEX_NOT_ARRAY" => 2,
    "A3E_INDEX_ELEMENT_TYPE" => 2,
    "A3E_INDEX_MIXED" => 2,
    "A3E_RANGE_ARITY" => 2,
    "A3E_RANGE_ENDPOINT_NOT_INTEGER" => 2,
    "A3E_VARIANT_NOT_OBJECT" => 2,
    "A3E_VARIANT_POSITION_MISSING" => 2,
    "A3E_VARIANT_POSITION_NOT_INTEGER" => 2,

    # ── Stage 3 — Intra-field ─────────────────────────────────────────────
    "A3E_POS_NOT_POSITIVE" => 3,
    "A3E_POS_DUPLICATE" => 3,
    "A3E_RANGE_ENDPOINT_NOT_POSITIVE" => 3,
    "A3E_RANGE_ORDER" => 3,
    "A3E_RANGE_OVERLAP" => 3,
    "A3E_VARIANT_POSITION_NOT_POSITIVE" => 3,

    # ── Stage 4 — Contextual ──────────────────────────────────────────────
    "A3E_POS_OUT_OF_BOUNDS" => 4,
    "A3E_RANGE_OUT_OF_BOUNDS" => 4,
    "A3E_VARIANT_OUT_OF_BOUNDS" => 4,
    "A3E_VARIANT_RESIDUE_MISMATCH" => 4,
)

"""
    A3_ISSUE_CODES

Every code in the registry, for coverage checks.
"""
const A3_ISSUE_CODES = collect(keys(A3_ISSUE_STAGES))

"""
    A3Issue(code, path, message)

A single validation issue.

- `code`: stable machine-readable code. Contractual.
- `path`: RFC 6901 JSON Pointer to the offending value. Contractual.
- `message`: human-readable explanation. Not contractual.

The inner constructor rejects a code that is not in [`A3_ISSUE_STAGES`], so a
mistyped code literal fails immediately rather than silently producing an issue
no consumer can match on.
"""
struct A3Issue
    code::String
    path::String
    message::String

    function A3Issue(code::AbstractString, path::AbstractString, message::AbstractString)
        haskey(A3_ISSUE_STAGES, code) ||
            error("'$code' is not a registered A3 issue code (see https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md)")
        new(String(code), String(path), String(message))
    end
end

"""
    stage(issue) -> Int

The validation stage an issue belongs to (1-4).
"""
stage(issue::A3Issue) = A3_ISSUE_STAGES[issue.code]

# The empty pointer denotes the whole document; writing it as "/" would be
# wrong, since that is the member named "".
function Base.show(io::IO, issue::A3Issue)
    where_ = isempty(issue.path) ? "<document>" : issue.path
    print(io, "[", issue.code, "] ", where_, ": ", issue.message)
end

Base.:(==)(a::A3Issue, b::A3Issue) =
    a.code == b.code && a.path == b.path && a.message == b.message

"""
    A3ValidationError(issues)

Raised when a document fails A3 validation.

Carries every issue found in the earliest failing validation stage. Validation
short-circuits at a stage boundary, so all issues in one error come from the
same stage.
"""
struct A3ValidationError <: Exception
    issues::Vector{A3Issue}
end

"""
    stage(err) -> Union{Int,Nothing}

The validation stage the reported issues belong to, or `nothing` if empty.
"""
stage(err::A3ValidationError) = isempty(err.issues) ? nothing : stage(err.issues[1])

"""
    A3ParseError(msg)

Raised when JSON parsing or file I/O fails.

A file that is not JSON has no path to report and nothing further to collect,
which is why this is a distinct type rather than an issue.
"""
struct A3ParseError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::A3ValidationError)
    print(io, "A3ValidationError: ", length(e.issues), " issue(s)")
    for issue in e.issues
        print(io, "\n  ", issue)
    end
end

Base.showerror(io::IO, e::A3ParseError) = print(io, "A3ParseError: ", e.msg)

# ─── JSON Pointer construction ────────────────────────────────────────────────

"""
    escape_token(token) -> String

Escape one reference token for inclusion in a JSON Pointer.

RFC 6901 escapes exactly two characters. `~` must be replaced before `/`, or a
key containing `/` would come out as `~01` instead of `~1`.
"""
escape_token(token::AbstractString) = replace(String(token), "~" => "~0", "/" => "~1")

"""
    pointer(base, token) -> String

Append one reference token or array subscript to a JSON Pointer.

`token` is a **raw** member name and is escaped here; an `Integer` subscript is
not. Do not pre-escape a name: `pointer(b, "a~1b")` yields `"a~01b"`, because the
`~` is escaped a second time.

```jldoctest
julia> RtemisA3.pointer("/annotations/site", "a/b")
"/annotations/site/a~1b"

julia> RtemisA3.pointer("", "\\\$schema")
"/\\\$schema"
```
"""
pointer(base::AbstractString, token::AbstractString) =
    string(base, "/", escape_token(token))
pointer(base::AbstractString, index::Integer) = string(base, "/", index)
