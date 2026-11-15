struct A3Metadata
    uniprot_id::String
    description::String
    reference::String
    organism::String
end

abstract type A3Index end

struct A3Position <: A3Index
    index::Vector{Int}
    type::String
end

struct A3Range <: A3Index
    index::Vector{Tuple{Int,Int}}
    type::String
end

struct VariantRecord
    position::Int
    extra::OrderedDict{String,Any}
end

# Annotation names are author-supplied and their order is part of the document,
# so these are OrderedDicts: a plain Dict would make serialization order
# nondeterministic run to run.
struct A3Annotations
    site::OrderedDict{String,A3Position}
    region::OrderedDict{String,A3Range}
    ptm::OrderedDict{String,A3Index}
    processing::OrderedDict{String,A3Index}
    variant::Vector{VariantRecord}
end

struct A3
    sequence::String
    annotations::A3Annotations
    metadata::A3Metadata
end

# Explicit equality for structs containing mutable fields (Vector, Dict)
Base.:(==)(a::A3Metadata, b::A3Metadata) =
    a.uniprot_id == b.uniprot_id &&
    a.description == b.description &&
    a.reference == b.reference &&
    a.organism == b.organism

Base.:(==)(a::A3Position, b::A3Position) = a.index == b.index && a.type == b.type
Base.:(==)(a::A3Range, b::A3Range) = a.index == b.index && a.type == b.type
Base.:(==)(a::VariantRecord, b::VariantRecord) =
    a.position == b.position && a.extra == b.extra
Base.:(==)(a::A3Annotations, b::A3Annotations) =
    a.site == b.site &&
    a.region == b.region &&
    a.ptm == b.ptm &&
    a.processing == b.processing &&
    a.variant == b.variant
Base.:(==)(a::A3, b::A3) =
    a.sequence == b.sequence && a.annotations == b.annotations && a.metadata == b.metadata
