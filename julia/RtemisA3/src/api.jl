"""
    create_a3(sequence; site, region, ptm, processing, variant, metadata) -> A3

Construct and validate an A3 object from raw (Dict/Array) inputs.
All annotation values use the same wire format as JSON: e.g.
`site = Dict("Phospho" => Dict("index" => [17, 18], "type" => ""))`.
"""
function create_a3(
    sequence;
    site = nothing,
    region = nothing,
    ptm = nothing,
    processing = nothing,
    variant = nothing,
    metadata = nothing,
)::A3
    annot = Dict{String,Any}()
    site !== nothing && (annot["site"] = site)
    region !== nothing && (annot["region"] = region)
    ptm !== nothing && (annot["ptm"] = ptm)
    processing !== nothing && (annot["processing"] = processing)
    variant !== nothing && (annot["variant"] = variant)

    raw = Dict{String,Any}(
        "\$schema" => _A3_SCHEMA_URI,
        "a3_version" => _A3_VERSION,
        "sequence" => sequence,
        "annotations" => annot,
        "metadata" => metadata !== nothing ? metadata : Dict{String,Any}(),
    )
    A3(raw)
end

"""
    residue_at(a3, position) -> Char

Return the amino acid (1-based) at `position`.
"""
function residue_at(a3::A3, position::Int)::Char
    n = length(a3.sequence)
    1 <= position <= n ||
        throw(BoundsError("position $position is out of bounds for sequence of length $n"))
    a3.sequence[position]
end

"""
    variants_at(a3, position) -> Vector{VariantRecord}

Return all variant records at the given 1-based `position`.
"""
variants_at(a3::A3, position::Int)::Vector{VariantRecord} =
    filter(v -> v.position == position, a3.annotations.variant)
