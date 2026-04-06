[![rtemis.a3 status badge](https://rtemis-org.r-universe.dev/rtemis.a3/badges/version)](https://rtemis-org.r-universe.dev/rtemis.a3)
[![PyPI version](https://img.shields.io/pypi/v/rtemis_a3.svg)](https://pypi.org/project/rtemis_a3/)
[![npm version](https://img.shields.io/npm/v/@rtemis/a3.svg)](https://www.npmjs.com/package/@rtemis/a3)
[![Crates.io Version](https://img.shields.io/crates/v/rtemis_a3)](https://crates.io/crates/rtemis_a3)

[![r-ci](https://github.com/rtemis-org/a3/actions/workflows/r-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/r-ci.yml)
[![python-ci](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml)
[![julia-ci](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml)
[![typescript-ci](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml)
[![rust-ci](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml)

# A3

A3 monorepo: specification and cross-language implementations of the Amino Acid Annotation format

[![rtemis a3 logo](https://www.rtemis.org/a3.svg)](https://a3.rtemis.org)

## Schema

[A3 JSON Schema](https://schema.rtemis.org/a3/v1/schema.json)

## Specification

- `specs/A3.md`: A3 implementation specification
- `specs/A3_S7`: R S7 implementation specification
- `specs/A3_Pydantic`: Python Pydantic implementation specification
- `specs/A3_Julia`: Julia implementation specification
- `specs/A3_Zod`: TypeScript Zod implementation specification
- `specs/A3_Rust`: Rust implementation specification

## Implementation

- `r/`: `rtemis.a3`
- `python/`: `rtemis.a3`
- `julia/`: `RtemisA3`
- `typescript/`: `@rtemis/a3`
- `rust/`: `rtemis_a3`

## Visualization

[rtemislive-draw](https://draw.rtemis.org) provides support for interactive visualization of A3 data using the [@rtemis/a3](https://www.npmjs.com/package/@rtemis/a3) TypeScript implementation.

![a3 draw screenshot](https://www.rtemis.org/draw-a3.webp)