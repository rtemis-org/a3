struct A3Metadata
    uniprot_id::String
    description::String
    reference::String
    organism::String
end

struct SiteEntry
    index::Vector{Int}
    type::String
end

struct RegionEntry
    index::Vector{Tuple{Int,Int}}
    type::String
end

# FlexEntry: index is either a list of positions or a list of ranges
struct FlexEntry
    index::Union{Vector{Int},Vector{Tuple{Int,Int}}}
    type::String
end

struct VariantRecord
    position::Int
    extra::Dict{String,Any}
end

struct A3Annotations
    site::Dict{String,SiteEntry}
    region::Dict{String,RegionEntry}
    ptm::Dict{String,FlexEntry}
    processing::Dict{String,FlexEntry}
    variant::Vector{VariantRecord}
end

struct A3
    sequence::String
    annotations::A3Annotations
    metadata::A3Metadata
end

# Explicit equality for structs containing mutable fields (Vector, Dict)
Base.:(==)(a::A3Metadata, b::A3Metadata) =
    a.uniprot_id == b.uniprot_id && a.description == b.description &&
    a.reference  == b.reference  && a.organism    == b.organism

Base.:(==)(a::SiteEntry,     b::SiteEntry)     = a.index == b.index && a.type == b.type
Base.:(==)(a::RegionEntry,   b::RegionEntry)   = a.index == b.index && a.type == b.type
Base.:(==)(a::FlexEntry,     b::FlexEntry)     = a.index == b.index && a.type == b.type
Base.:(==)(a::VariantRecord, b::VariantRecord) = a.position == b.position && a.extra == b.extra
