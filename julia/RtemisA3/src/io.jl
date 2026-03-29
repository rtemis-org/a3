# ─── Serialization ────────────────────────────────────────────────────────────

_idx_to_json(idx::Vector{Int})            = idx
_idx_to_json(idx::Vector{Tuple{Int,Int}}) = [collect(r) for r in idx]

_to_dict(e::SiteEntry)   = Dict("index" => e.index,               "type" => e.type)
_to_dict(e::RegionEntry) = Dict("index" => _idx_to_json(e.index), "type" => e.type)
_to_dict(e::FlexEntry)   = Dict("index" => _idx_to_json(e.index), "type" => e.type)

function _to_dict(v::VariantRecord)
    d = Dict{String,Any}("position" => v.position)
    merge!(d, v.extra)
    d
end

function to_dict(a3::A3)::Dict{String,Any}
    Dict{String,Any}(
        "sequence" => a3.sequence,
        "annotations" => Dict{String,Any}(
            "site"       => Dict(k => _to_dict(v) for (k, v) in a3.annotations.site),
            "region"     => Dict(k => _to_dict(v) for (k, v) in a3.annotations.region),
            "ptm"        => Dict(k => _to_dict(v) for (k, v) in a3.annotations.ptm),
            "processing" => Dict(k => _to_dict(v) for (k, v) in a3.annotations.processing),
            "variant"    => [_to_dict(v) for v in a3.annotations.variant],
        ),
        "metadata" => Dict{String,Any}(
            "uniprot_id"  => a3.metadata.uniprot_id,
            "description" => a3.metadata.description,
            "reference"   => a3.metadata.reference,
            "organism"    => a3.metadata.organism,
        ),
    )
end

# ─── JSON ─────────────────────────────────────────────────────────────────────

"""
    a3_from_json(text) -> A3

Parse an A3 object from a JSON string.
"""
function a3_from_json(text::AbstractString)::A3
    raw = try
        JSON.parse(text)
    catch e
        throw(A3ParseError("JSON parse error: $e"))
    end
    raw isa AbstractDict ||
        throw(A3ParseError("JSON root must be an object"))
    A3(raw)
end

"""
    a3_to_json(a3; indent=nothing) -> String

Serialize an A3 object to a JSON string. Pass `indent` for pretty-printing.
"""
function a3_to_json(a3::A3; indent::Union{Int,Nothing}=nothing)::String
    d = to_dict(a3)
    indent === nothing ? JSON.json(d) : JSON.json(d, indent)
end

# ─── File I/O ─────────────────────────────────────────────────────────────────

"""
    read_a3json(path) -> A3

Read an A3 object from a JSON file on disk.
"""
function read_a3json(path::AbstractString)::A3
    text = try
        read(path, String)
    catch e
        throw(A3ParseError("failed to read '$path': $e"))
    end
    a3_from_json(text)
end

"""
    write_a3json(a3, path; indent=2)

Write an A3 object to a JSON file on disk.
"""
function write_a3json(a3::A3, path::AbstractString; indent::Int=2)
    text = a3_to_json(a3; indent=indent)
    try
        Base.write(path, text)
    catch e
        throw(A3ParseError("failed to write '$path': $e"))
    end
    nothing
end
