# ─── Structural validation ────────────────────────────────────────────────────

function validate_sequence(raw, path::String)::String
    raw isa AbstractString ||
        throw(A3ValidationError("$path: expected string, got $(typeof(raw))"))
    isempty(raw) &&
        throw(A3ValidationError("$path: must not be empty"))
    upper = uppercase(String(raw))
    length(upper) < 2 &&
        throw(A3ValidationError("$path: must be at least 2 characters"))
    for c in upper
        (c in 'A':'Z' || c == '*') ||
            throw(A3ValidationError("$path: invalid character '$c' (must match [A-Z*])"))
    end
    return upper
end

function validate_positions(raw::AbstractVector, path::String)::Vector{Int}
    positions = Vector{Int}()
    for (i, v) in enumerate(raw)
        v isa Integer ||
            throw(A3ValidationError("$path[$i]: expected integer, got $(typeof(v))"))
        v >= 1 ||
            throw(A3ValidationError("$path[$i]: position $v must be >= 1"))
        push!(positions, Int(v))
    end
    return sort_dedup(positions)
end

function validate_ranges(raw::AbstractVector, path::String)::Vector{Tuple{Int,Int}}
    ranges = Vector{Tuple{Int,Int}}()
    for (i, v) in enumerate(raw)
        (v isa AbstractVector && length(v) == 2) ||
            throw(A3ValidationError("$path[$i]: expected [start, end] pair, got $v"))
        s, e = v[1], v[2]
        s isa Integer ||
            throw(A3ValidationError("$path[$i]: range start must be integer, got $(typeof(s))"))
        e isa Integer ||
            throw(A3ValidationError("$path[$i]: range end must be integer, got $(typeof(e))"))
        s >= 1 ||
            throw(A3ValidationError("$path[$i]: start $s must be >= 1"))
        e >= 1 ||
            throw(A3ValidationError("$path[$i]: end $e must be >= 1"))
        s < e  ||
            throw(A3ValidationError("$path[$i]: start $s must be strictly less than end $e " *
                "(degenerate single-position ranges must use a position-indexed family)"))
        push!(ranges, (Int(s), Int(e)))
    end
    sorted = sort_ranges(ranges)
    check_no_overlap(sorted, path)
    return sorted
end

function validate_flex_index(raw::AbstractVector, path::String)::Union{Vector{Int},Vector{Tuple{Int,Int}}}
    isempty(raw) && return Int[]
    raw[1] isa AbstractVector ? validate_ranges(raw, path) : validate_positions(raw, path)
end

# ─── Entry parsers ────────────────────────────────────────────────────────────

function _parse_entry_base(raw, path::String)
    raw isa AbstractDict ||
        throw(A3ValidationError(
            "$path: expected object with 'index' and 'type' fields, got $(typeof(raw)) " *
            "(bare arrays are not accepted)"
        ))
    for k in keys(raw)
        k in ("index", "type") ||
            throw(A3ValidationError("$path: unknown field '$k' (only 'index' and 'type' are allowed)"))
    end
    haskey(raw, "index") ||
        throw(A3ValidationError("$path: missing required field 'index'"))
    index_raw = raw["index"]
    index_raw isa AbstractVector ||
        throw(A3ValidationError("$path.index: expected array"))
    type_val = get(raw, "type", "")
    type_val isa AbstractString ||
        throw(A3ValidationError("$path.type: expected string, got $(typeof(type_val))"))
    return index_raw, String(type_val)
end

function parse_site_entry(raw, path::String)::SiteEntry
    ir, t = _parse_entry_base(raw, path)
    SiteEntry(validate_positions(ir, "$path.index"), t)
end

function parse_region_entry(raw, path::String)::RegionEntry
    ir, t = _parse_entry_base(raw, path)
    RegionEntry(validate_ranges(ir, "$path.index"), t)
end

function parse_flex_entry(raw, path::String)::FlexEntry
    ir, t = _parse_entry_base(raw, path)
    FlexEntry(validate_flex_index(ir, "$path.index"), t)
end

function parse_variant(raw, path::String)::VariantRecord
    raw isa AbstractDict ||
        throw(A3ValidationError("$path: expected object"))
    haskey(raw, "position") ||
        throw(A3ValidationError("$path: missing required field 'position'"))
    pos = raw["position"]
    pos isa Integer ||
        throw(A3ValidationError("$path.position: expected integer, got $(typeof(pos))"))
    pos >= 1 ||
        throw(A3ValidationError("$path.position: must be >= 1, got $pos"))
    extra = Dict{String,Any}()
    for (k, v) in raw
        k == "position" && continue
        is_json_compatible(v) ||
            throw(A3ValidationError("$path.$k: value is not JSON-compatible"))
        extra[k] = v
    end
    VariantRecord(Int(pos), extra)
end

function parse_named_map(raw, path::String, parser::Function, ::Type{T}) where T
    raw isa AbstractDict ||
        throw(A3ValidationError("$path: expected object"))
    result = Dict{String,T}()
    for (name, entry) in raw
        isempty(name) &&
            throw(A3ValidationError("$path: annotation name must be non-empty string"))
        result[String(name)] = parser(entry, "$path.$name")
    end
    return result
end

function parse_annotations(raw, path::String)::A3Annotations
    raw isa AbstractDict ||
        throw(A3ValidationError("$path: expected object"))
    for k in keys(raw)
        k in ("site", "region", "ptm", "processing", "variant") ||
            throw(A3ValidationError("$path: unknown annotation family '$k' " *
                "(must be one of: site, region, ptm, processing, variant)"))
    end

    empty_dict() = Dict{String,Any}()

    site       = parse_named_map(get(raw, "site",       empty_dict()), "$path.site",       parse_site_entry,   SiteEntry)
    region     = parse_named_map(get(raw, "region",     empty_dict()), "$path.region",     parse_region_entry, RegionEntry)
    ptm        = parse_named_map(get(raw, "ptm",        empty_dict()), "$path.ptm",        parse_flex_entry,   FlexEntry)
    processing = parse_named_map(get(raw, "processing", empty_dict()), "$path.processing", parse_flex_entry,   FlexEntry)

    variant_raw = get(raw, "variant", Any[])
    variant_raw isa AbstractVector ||
        throw(A3ValidationError("$path.variant: expected array"))
    variants = [parse_variant(v, "$path.variant[$i]") for (i, v) in enumerate(variant_raw)]

    A3Annotations(site, region, ptm, processing, variants)
end

function parse_metadata(raw, path::String)::A3Metadata
    raw isa AbstractDict ||
        throw(A3ValidationError("$path: expected object"))
    for k in keys(raw)
        k in ("uniprot_id", "description", "reference", "organism") ||
            throw(A3ValidationError("$path: unknown field '$k' " *
                "(must be one of: uniprot_id, description, reference, organism)"))
    end
    get_str(field) = begin
        v = get(raw, field, "")
        v isa AbstractString ||
            throw(A3ValidationError("$path.$field: expected string, got $(typeof(v))"))
        String(v)
    end
    A3Metadata(get_str("uniprot_id"), get_str("description"), get_str("reference"), get_str("organism"))
end

# ─── Contextual validation (Stage 2) ─────────────────────────────────────────

function validate_bounds(seq::String, annotations::A3Annotations)
    n = length(seq)
    chk(pos, path) = 1 <= pos <= n ||
        throw(A3ValidationError(
            "$path: position $pos is out of bounds for sequence of length $n (must be 1-$n)"
        ))
    chk_range(r, path) = begin
        chk(r[1], "$path start")
        chk(r[2], "$path end")
    end

    for (name, entry) in annotations.site
        for (i, p) in enumerate(entry.index)
            chk(p, "annotations.site.$name.index[$i]")
        end
    end
    for (name, entry) in annotations.region
        for (i, r) in enumerate(entry.index)
            chk_range(r, "annotations.region.$name.index[$i]")
        end
    end
    for (name, entry) in annotations.ptm
        if entry.index isa Vector{Int}
            for (i, p) in enumerate(entry.index); chk(p, "annotations.ptm.$name.index[$i]"); end
        else
            for (i, r) in enumerate(entry.index); chk_range(r, "annotations.ptm.$name.index[$i]"); end
        end
    end
    for (name, entry) in annotations.processing
        if entry.index isa Vector{Int}
            for (i, p) in enumerate(entry.index); chk(p, "annotations.processing.$name.index[$i]"); end
        else
            for (i, r) in enumerate(entry.index); chk_range(r, "annotations.processing.$name.index[$i]"); end
        end
    end
    for (i, v) in enumerate(annotations.variant)
        chk(v.position, "annotations.variant[$i].position")
    end
end

# ─── A3 outer constructor ─────────────────────────────────────────────────────

function A3(raw::AbstractDict)
    for k in keys(raw)
        k in ("sequence", "annotations", "metadata") ||
            throw(A3ValidationError("unknown top-level field '$k' " *
                "(must be one of: sequence, annotations, metadata)"))
    end
    haskey(raw, "sequence") ||
        throw(A3ValidationError("missing required field 'sequence'"))

    seq         = validate_sequence(raw["sequence"], "sequence")
    annotations = parse_annotations(get(raw, "annotations", Dict{String,Any}()), "annotations")
    metadata    = parse_metadata(get(raw, "metadata", Dict{String,Any}()), "metadata")

    validate_bounds(seq, annotations)
    A3(seq, annotations, metadata)
end
