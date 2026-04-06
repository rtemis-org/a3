module RtemisA3

using JSON

include("errors.jl")
include("types.jl")
include("normalize.jl")
include("validate.jl")
include("io.jl")
include("api.jl")

export A3ValidationError, A3ParseError
export A3Metadata, A3Index, A3Position, A3Range, VariantRecord, A3Annotations, A3
export a3_from_json, a3_to_json, read_a3json, write_a3json
export create_a3, residue_at, variants_at

end # module RtemisA3
