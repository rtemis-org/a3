using Test
using JSON
using OrderedCollections
using RtemisA3
using RtemisA3: sort_ranges, is_json_compatible, stage

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

@testset "sort_ranges" begin
    # Normalization is total: it sorts, it never rejects. Overlap and ordering
    # are validation's job, and both run after this sort.
    @test sort_ranges([(3, 5), (1, 2)]) == [(1, 2), (3, 5)]
    @test sort_ranges([(1, 4), (1, 2)]) == [(1, 2), (1, 4)]
    @test sort_ranges([(12, 8), (3, 3)]) == [(3, 3), (12, 8)]
end

@testset "JSON Pointer construction" begin
    # RFC 6901 escapes exactly two characters, and `~` must go before `/`.
    @test RtemisA3.escape_token("a/b") == "a~1b"
    @test RtemisA3.escape_token("a~b") == "a~0b"
    @test RtemisA3.escape_token("a~1b") == "a~01b"
    @test RtemisA3.escape_token("a.b") == "a.b"
    @test RtemisA3.pointer("/annotations/site", "a/b") == "/annotations/site/a~1b"
    @test RtemisA3.pointer("/annotations/site", "") == "/annotations/site/"
    @test RtemisA3.pointer("/annotations/variant", 3) == "/annotations/variant/3"
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
    @test isempty(a.annotations.variant[2].extra)

    # missing position
    val_err(() -> create_a3("MAEPRQ"; variant = [Dict("from" => "E")]))

    # position out of bounds
    val_err(() -> create_a3("MAEPRQ"; variant = [Dict("position" => 10)]))

    # A non-JSON-compatible member is a construction-path guard, not a
    # validation issue: no such value can come out of JSON.parse, so it has no
    # A3 code.
    @test_throws ArgumentError create_a3(
        "MAEPRQ";
        variant = [Dict("position" => 1, "fn" => x -> x)],
    )

    # The residue rule fires only when `from` is a single character that
    # disagrees with the sequence. Residue 3 of MAEPRQ is E.
    e = val_err(() -> create_a3("MAEPRQ"; variant = [Dict("position" => 3, "from" => "K")]))
    @test [(i.code, i.path) for i in e.issues] == [("A3E_VARIANT_RESIDUE_MISMATCH", "/annotations/variant/0/from")]
    # Absent, or of another shape, is not this rule's problem.
    @test create_a3("MAEPRQ"; variant = [Dict("position" => 3, "from" => "Glu")]) isa A3
    @test create_a3("MAEPRQ"; variant = [Dict("position" => 3, "from" => "e")]) isa A3
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
        @test a.metadata.uniprot_id == "P10636-8"
        @test haskey(a.annotations.site, "AT8 epitope")
        @test haskey(a.annotations.region, "R1")
        @test haskey(a.annotations.ptm, "Phosphorylation")
        @test haskey(a.annotations.processing, "Chain")
        @test !isempty(a.annotations.variant)

        # round-trip
        json1 = a3_to_json(a)
        b = a3_from_json(json1)
        @test b.sequence == a.sequence
        @test b.metadata == a.metadata
        @test b.annotations.site == a.annotations.site
        @test b.annotations.region == a.annotations.region
        @test b.annotations.ptm == a.annotations.ptm
        @test b.annotations.processing == a.annotations.processing
        @test b.annotations.variant == a.annotations.variant
    else
        @warn "Example file not found, skipping: $example_path"
    end
end

# ─── Error messages ───────────────────────────────────────────────────────────

@testset "issues carry codes, paths, and messages" begin
    e = val_err(
        () -> create_a3("MAEPRQ"; site = Dict("x" => Dict("index" => [10], "type" => ""))),
    )
    @test length(e.issues) == 1
    @test e.issues[1].code == "A3E_POS_OUT_OF_BOUNDS"
    @test e.issues[1].path == "/annotations/site/x/index/0"
    @test stage(e) == 4
    # The message is not contractual, but it must name the offending value.
    @test occursin("out of bounds", e.issues[1].message)
    @test occursin("1-6", e.issues[1].message)

    e2 = val_err(() -> create_a3("M1"))
    @test [i.code for i in e2.issues] == ["A3E_SEQ_CHARSET"]
    @test stage(e2) == 2

    # Length and charset are independent rules; a one-character digit trips both,
    # and within a stage every issue is collected.
    e3 = val_err(() -> create_a3("1"))
    @test [i.code for i in e3.issues] == ["A3E_SEQ_TOO_SHORT", "A3E_SEQ_CHARSET"]

    # A file that is not JSON has no path to report and nothing to collect.
    @test parse_err(() -> a3_from_json("{invalid json")) isa A3ParseError
end

@testset "collect-all and staging" begin
    # Both envelope members are wrong: a fail-fast implementation reports one.
    e = val_err(
        () -> A3(
            OrderedDict(
                "\$schema" => "urn:a3",
                "a3_version" => "0.9.0",
                "sequence" => "MA",
            ),
        ),
    )
    @test [(i.code, i.path) for i in e.issues] == [
        ("A3E_ENVELOPE_SCHEMA_MISMATCH", "/\$schema"),
        ("A3E_ENVELOPE_VERSION_MISMATCH", "/a3_version"),
    ]

    # A Stage 2 issue suppresses every would-be Stage 4 issue.
    e2 = val_err(
        () -> create_a3(
            "MAEP1Q";
            site = Dict("s" => Dict("index" => [90, 91, 92], "type" => "")),
        ),
    )
    @test [i.code for i in e2.issues] == ["A3E_SEQ_CHARSET"]
end

@testset "annotations and metadata are optional" begin
    a = A3(
        OrderedDict(
            "\$schema" => "https://schema.rtemis.org/a3/v1/schema.json",
            "a3_version" => "1.0.0",
            "sequence" => "MAEPRQ",
        ),
    )
    @test a.sequence == "MAEPRQ"
    @test isempty(a.annotations.site)
    @test a.metadata.uniprot_id == ""
end

@testset "annotation name order is preserved" begin
    text = """{"\$schema":"https://schema.rtemis.org/a3/v1/schema.json",
               "a3_version":"1.0.0","sequence":"MAEPRQ",
               "annotations":{"site":{"zeta":{"index":[1]},"alpha":{"index":[2]},
                                      "Mu":{"index":[3]}}}}"""
    a = a3_from_json(text)
    @test collect(keys(a.annotations.site)) == ["zeta", "alpha", "Mu"]
end

# ─── Conformance ──────────────────────────────────────────────────────────────

include("conformance.jl")
