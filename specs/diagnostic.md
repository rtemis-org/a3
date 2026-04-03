# Diagnostic mode

Principled step-by-step check of A3 files. All errors are accumulated and
reported together. Steps marked **[fatal]** halt diagnostics if they fail —
subsequent steps cannot run without their output. All other steps are
**continuable**: failure is recorded but checking proceeds.

1. **Valid JSON** [fatal]
   Check that the input is syntactically valid JSON.

2. **Envelope** — `$schema` and `a3_version`
   Check that both fields are present and equal the required values.

3. **Top-level field presence, types, and no unknown keys** [fatal per field]
   Check that `sequence` (string), `annotations` (object), and `metadata`
   (object) are present and of the correct type, and that no unknown top-level
   keys exist. A field with the wrong type is fatal for the steps that depend
   on it (e.g. a non-object `annotations` blocks step 5).

4. **Sequence value**
   Check character validity (standard amino acid letters or `*`) and minimum
   length. Required for bounds checking in step 5; if this step fails,
   bounds checking is skipped.

5. **Annotation families**, one by one: `site`, `region`, `ptm`, `processing`, `variant`
   For each family:
   a. Correct container type (object for site/region/ptm/processing, array for variant).
   b. Entry structure and index field types.
   c. Bounds: every position and range endpoint within sequence length
      (skipped if step 4 failed).

6. **Metadata fields**
   Check that all fields (`uniprot_id`, `description`, `reference`, `organism`)
   are strings if present, and that no unknown metadata keys exist.
