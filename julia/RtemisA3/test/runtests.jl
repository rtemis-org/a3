using Test
using RtemisA3
using RtemisA3: sort_dedup, sort_ranges, check_no_overlap, is_json_compatible

# ─── Helpers ─────────────────────────────────────────────────────────────────

err(f) =
    try
        ;
        f();
        nothing;
    catch e
        ;
        e;
    end
val_err(f) = begin
    e = err(f);
    @test e isa A3ValidationError;
    e
end
parse_err(f) = begin
    e = err(f);
    @test e isa A3ParseError;
    e
end

# ─── Normalization ────────────────────────────────────────────────────────────

@testset "sort_dedup" begin
    # sort_dedup is a normalization utility (future clean API), not a validator
    @test sort_dedup([3, 1, 2, 2, 1]) == [1, 2, 3]
    @test sort_dedup(Int[]) == Int[]
    @test sort_dedup([5]) == [5]
end

@testset "sort_ranges" begin
    @test sort_ranges([(3, 5), (1, 2)]) == [(1, 2), (3, 5)]
    @test sort_ranges([(1, 4), (1, 2)]) == [(1, 2), (1, 4)]
end

@testset "check_no_overlap" begin
    @test check_no_overlap([(1, 3), (5, 7)], "x") === nothing
    @test check_no_overlap([(1, 5), (6, 8)], "x") === nothing  # adjacent ok
    val_err(() -> check_no_overlap([(1, 5), (5, 8)], "x"))      # touching = overlap
    val_err(() -> check_no_overlap([(1, 5), (3, 8)], "x"))      # overlapping
end

@testset "is_json_compatible" begin
    @test is_json_compatible(nothing)
    @test is_json_compatible(true)
    @test is_json_compatible(42)
    @test is_json_compatible(3.14)
    @test is_json_compatible("hello")
    @test is_json_compatible([1, "a", nothing])
    @test is_json_compatible(Dict("a" => 1))
    @test !is_json_compatible(x -> x)       # function
    @test !is_json_compatible(Dict(1 => "a"))  # non-string key
end

# ─── Sequence validation ──────────────────────────────────────────────────────

@testset "sequence validation" begin
    a = create_a3("MAEPR")
    @test a.sequence == "MAEPR"

    # lowercase normalized
    b = create_a3("maepr")
    @test b.sequence == "MAEPR"

    # stop codon allowed
    c = create_a3("MA*")
    @test c.sequence == "MA*"

    val_err(() -> create_a3(""))         # empty
    val_err(() -> create_a3("M"))        # too short
    val_err(() -> create_a3("M1"))       # invalid char
    val_err(() -> create_a3("M-A"))      # invalid char
end

# ─── Site entries ─────────────────────────────────────────────────────────────

@testset "site entries" begin
    a = create_a3("MAEPRQ"; site = Dict("test" => Dict("index" => [3, 1, 2], "type" => "")))
    @test a.annotations.site["test"].index == [1, 2, 3]  # sorted

    # duplicate positions rejected
    val_err(
        () -> create_a3(
            "MAEPRQ";
            site = Dict("test" => Dict("index" => [3, 1, 2, 2], "type" => "")),
        ),
    )

    # out of bounds
    val_err(
        () -> create_a3("MAEPRQ"; site = Dict("x" => Dict("index" => [7], "type" => ""))),
    )

    # bare array rejected
    val_err(() -> create_a3("MAEPRQ"; site = Dict("x" => [1, 2])))

    # empty annotation name
    val_err(
        () -> create_a3("MAEPRQ"; site = Dict("" => Dict("index" => [1], "type" => ""))),
    )
end

# ─── Region entries ───────────────────────────────────────────────────────────

@testset "region entries" begin
    a = create_a3(
        "MAEPRQFEV";
        region = Dict("span" => Dict("index" => [[4, 7], [1, 3]], "type" => "test")),
    )
    @test a.annotations.region["span"].index == [(1, 3), (4, 7)]  # sorted
    @test a.annotations.region["span"].type == "test"

    # start == end rejected (degenerate)
    val_err(
        () -> create_a3(
            "MAEPRQ";
            region = Dict("x" => Dict("index" => [[2, 2]], "type" => "")),
        ),
    )

    # start > end rejected
    val_err(
        () -> create_a3(
            "MAEPRQ";
            region = Dict("x" => Dict("index" => [[3, 1]], "type" => "")),
        ),
    )

    # overlapping ranges rejected
    val_err(
        () -> create_a3(
            "MAEPRQFEVME";
            region = Dict("x" => Dict("index" => [[1, 5], [4, 8]], "type" => "")),
        ),
    )

    # adjacent ranges allowed
    a2 = create_a3(
        "MAEPRQFEVME";
        region = Dict("x" => Dict("index" => [[1, 4], [5, 8]], "type" => "")),
    )
    @test length(a2.annotations.region["x"].index) == 2
end

# ─── FlexEntry (ptm / processing) ────────────────────────────────────────────

@testset "flex entries" begin
    # positions
    a = create_a3("MAEPRQ"; ptm = Dict("Phospho" => Dict("index" => [2, 4], "type" => "")))
    @test a.annotations.ptm["Phospho"] isa A3Position
    @test a.annotations.ptm["Phospho"].index == [2, 4]

    # ranges
    b = create_a3(
        "MAEPRQFEV";
        processing = Dict(
            "Signal" => Dict("index" => [[1, 5]], "type" => "signal peptide"),
        ),
    )
    @test b.annotations.processing["Signal"] isa A3Range
    @test b.annotations.processing["Signal"].index == [(1, 5)]

    # empty index
    c = create_a3("MAEPRQ"; ptm = Dict("empty" => Dict("index" => [], "type" => "")))
    @test c.annotations.ptm["empty"] isa A3Position
    @test c.annotations.ptm["empty"].index == Int[]
end

# ─── Variants ─────────────────────────────────────────────────────────────────

@testset "variants" begin
    a = create_a3(
        "MAEPRQ";
        variant = [
            Dict("position" => 3, "from" => "E", "to" => "K"),
            Dict("position" => 5),
        ],
    )
    @test length(a.annotations.variant) == 2
    @test a.annotations.variant[1].position == 3
    @test a.annotations.variant[1].extra["from"] == "E"
    @test a.annotations.variant[2].extra == Dict{String,Any}()

    # missing position
    val_err(() -> create_a3("MAEPRQ"; variant = [Dict("from" => "E")]))

    # position out of bounds
    val_err(() -> create_a3("MAEPRQ"; variant = [Dict("position" => 10)]))

    # non-JSON-compatible extra field
    val_err(() -> create_a3("MAEPRQ"; variant = [Dict("position" => 1, "fn" => x -> x)]))
end

# ─── Metadata ─────────────────────────────────────────────────────────────────

@testset "metadata" begin
    a = create_a3(
        "MAEPRQ";
        metadata = Dict("uniprot_id" => "P12345", "organism" => "Homo sapiens"),
    )
    @test a.metadata.uniprot_id == "P12345"
    @test a.metadata.organism == "Homo sapiens"
    @test a.metadata.description == ""
    @test a.metadata.reference == ""

    # unknown key rejected
    val_err(() -> create_a3("MAEPRQ"; metadata = Dict("unknown_field" => "x")))
end

# ─── Unknown keys rejected ────────────────────────────────────────────────────

@testset "unknown keys" begin
    val_err(
        () -> A3(
            Dict(
                "\$schema" => "https://schema.rtemis.org/a3/v1/schema.json",
                "a3_version" => "1.0.0",
                "sequence" => "MAEPRQ",
                "extra" => "bad",
            ),
        ),
    )
    val_err(
        () -> create_a3(
            "MAEPRQ";
            site = Dict("x" => Dict("index" => [1], "type" => "", "extra" => "bad")),
        ),
    )
end

# ─── Query functions ──────────────────────────────────────────────────────────

@testset "residue_at" begin
    a = create_a3("MAEPRQ")
    @test residue_at(a, 1) == 'M'
    @test residue_at(a, 6) == 'Q'
    @test_throws BoundsError residue_at(a, 0)
    @test_throws BoundsError residue_at(a, 7)
end

@testset "variants_at" begin
    a = create_a3(
        "MAEPRQ";
        variant = [
            Dict("position" => 3, "from" => "E"),
            Dict("position" => 3, "from" => "E", "to" => "K"),
            Dict("position" => 5),
        ],
    )
    @test length(variants_at(a, 3)) == 2
    @test length(variants_at(a, 5)) == 1
    @test length(variants_at(a, 1)) == 0
end

# ─── JSON serialization ───────────────────────────────────────────────────────

@testset "a3_to_json / a3_from_json" begin
    a = create_a3(
        "MAEPRQ";
        site = Dict("key" => Dict("index" => [1, 3], "type" => "test")),
        region = Dict("span" => Dict("index" => [[2, 5]], "type" => "")),
        ptm = Dict("Phospho" => Dict("index" => [2, 4], "type" => "")),
        variant = [Dict("position" => 3, "from" => "E", "to" => "K")],
        metadata = Dict("uniprot_id" => "P99999", "organism" => "Mus musculus"),
    )
    json_str = a3_to_json(a; indent = 2)
    @test json_str isa String

    b = a3_from_json(json_str)
    @test b.sequence == a.sequence
    @test b.metadata.uniprot_id == "P99999"
    @test b.annotations.site["key"].index == [1, 3]
    @test b.annotations.region["span"].index == [(2, 5)]
    @test b.annotations.ptm["Phospho"].index == [2, 4]
    @test b.annotations.variant[1].position == 3
    @test b.annotations.variant[1].extra["from"] == "E"

    # all 5 families always present in serialized output
    annot = RtemisA3.to_dict(b)["annotations"]
    @test haskey(annot, "processing")
    @test haskey(annot, "site")
    @test haskey(annot, "region")
    @test haskey(annot, "ptm")
    @test haskey(annot, "variant")
end

@testset "JSON round-trip completeness" begin
    a = create_a3("MAEPRQ")
    d = RtemisA3.to_dict(a)
    annot = d["annotations"]
    @test haskey(annot, "site")
    @test haskey(annot, "region")
    @test haskey(annot, "ptm")
    @test haskey(annot, "processing")
    @test haskey(annot, "variant")
    @test haskey(d, "metadata")
end

# ─── Round-trip with example file ────────────────────────────────────────────

@testset "round-trip: mapt.a3.json" begin
    example_path = joinpath(@__DIR__, "..", "..", "..", "examples", "mapt.a3.json")
    if isfile(example_path)
        a = read_a3json(example_path)
        @test length(a.sequence) == 441
        @test a.metadata.uniprot_id == "P10636"
        @test haskey(a.annotations.site, "Disease_associated_variant")
        @test haskey(a.annotations.region, "KXGS")
        @test haskey(a.annotations.ptm, "Phosphorylation")
        @test isempty(a.annotations.processing)
        @test isempty(a.annotations.variant)

        # round-trip
        json1 = a3_to_json(a)
        b = a3_from_json(json1)
        @test b.sequence == a.sequence
        @test b.metadata == a.metadata
        @test b.annotations.site == a.annotations.site
        @test b.annotations.region == a.annotations.region
        @test b.annotations.ptm == a.annotations.ptm
    else
        @warn "Example file not found, skipping: $example_path"
    end
end

# ─── Error messages ───────────────────────────────────────────────────────────

@testset "error messages" begin
    e = val_err(
        () -> create_a3("MAEPRQ"; site = Dict("x" => Dict("index" => [10], "type" => ""))),
    )
    @test occursin("out of bounds", e.msg)
    @test occursin("1-6", e.msg)

    e2 = val_err(() -> create_a3("M1"))
    @test occursin("invalid character", e2.msg)

    e3 = parse_err(() -> a3_from_json("{invalid json"))
    @test e3 isa A3ParseError
end
