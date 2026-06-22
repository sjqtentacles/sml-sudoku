# sml-sudoku

[![CI](https://github.com/sjqtentacles/sml-sudoku/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-sudoku/actions/workflows/ci.yml)

A self-contained 9x9 Sudoku model and **deterministic** constraint solver in
pure Standard ML. Candidate elimination over rows / columns / boxes is combined
with backtracking guided by the minimum-remaining-values (MRV) heuristic, so a
given puzzle always produces the **same** solution under both **MLton** and
**Poly/ML**.

No dependencies, no FFI, no threads, no clock, no randomness: same input, same
output. Cell selection (lowest index on an MRV tie) and value order (ascending
candidates) are fixed, so solutions are reproducible and byte-identical across
compilers.

## Scope decision: self-contained solver (no minikanren)

The master scope allowed *either* vendoring `sml-minikanren` *or* a dedicated
constraint solver. This library ships a **self-contained, dependency-free**
constraint-propagation + MRV-backtracking solver (Layout A). A purpose-built
Sudoku solver is dramatically faster than a relational/minikanren encoding —
it solves Arto Inkala's "world's hardest" puzzle in milliseconds — which keeps
CI test runtime small and fully reproducible. There is therefore no external
dependency to vendor.

## API

```sml
structure Sudoku : sig
  type board
  val size : int                 (* 9 *)
  val boxSize : int              (* 3 *)
  val empty      : board
  val fromString : string -> board option   (* 81 chars; '.'/'0' blank *)
  val toString   : board -> string          (* 81 chars, '.' for blank *)
  val pretty     : board -> string
  val get   : board -> int -> int -> int           (* value at (r, c) *)
  val set   : board -> int -> int -> int -> board  (* persistent *)
  val clues : board -> int
  val candidates : board -> int -> int -> int list
  val isValid    : board -> bool
  val isComplete : board -> bool
  val solve : board -> board option
  val countSolutions : board -> int -> int   (* counts up to cap *)
  val solveAll : board -> int -> board list   (* up to cap solutions *)
end
```

Rows and columns are 0-based; `(r, c)` is row `r`, column `c`. A board is parsed
from an 81-character string read left-to-right, top-to-bottom, where `.` or `0`
mark a blank and `1`..`9` a given clue.

## Example

```sml
val SOME b = Sudoku.fromString
  "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"
val 30 = Sudoku.clues b
val 1  = Sudoku.countSolutions b 2          (* exactly one solution: unique *)
val SOME sol = Sudoku.solve b
val "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
    = Sudoku.toString sol
```

Running [`examples/demo.sml`](examples/demo.sml) with `make example` prints:

```
Puzzle (the Wikipedia example):

5 3 . | . 7 . | . . .
6 . . | 1 9 5 | . . .
. 9 8 | . . . | . 6 .
------+-------+------
8 . . | . 6 . | . . 3
4 . . | 8 . 3 | . . 1
7 . . | . 2 . | . . 6
------+-------+------
. 6 . | . . . | 2 8 .
. . . | 4 1 9 | . . 5
. . . | . 8 . | . 7 9

clues: 30
solutions (cap 2): 1  (1 = unique)

Solution:

5 3 4 | 6 7 8 | 9 1 2
6 7 2 | 1 9 5 | 3 4 8
1 9 8 | 3 4 2 | 5 6 7
------+-------+------
8 5 9 | 7 6 1 | 4 2 3
4 2 6 | 8 5 3 | 7 9 1
7 1 3 | 9 2 4 | 8 5 6
------+-------+------
9 6 1 | 5 3 7 | 2 8 4
2 8 7 | 4 1 9 | 6 3 5
3 4 5 | 2 8 6 | 1 7 9

as string: 534678912672195348198342567859761423426853791713924856961537284287419635345286179
```

## Build & test

Requires [MLton](http://mlton.org/) and/or [Poly/ML](https://polyml.org/).

```sh
make test        # build + run the suite under MLton
make test-poly   # run the suite under Poly/ML
make all-tests   # both
make example     # build + run the demo
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-sudoku
smlpkg sync
```

Reference `lib/github.com/sjqtentacles/sml-sudoku/sudoku.mlb` from your own
`.mlb` (MLton / MLKit), or feed `sources.mlb` to `tools/polybuild` (Poly/ML).

## Layout

```
sml.pkg                                       smlpkg manifest
Makefile                                      MLton + Poly/ML targets
.github/workflows/ci.yml                      CI: MLton + Poly/ML
lib/github.com/sjqtentacles/sml-sudoku/
  sudoku.sig     SUDOKU signature
  sudoku.sml     board model + MRV solver
  sources.mlb    ordered source list
  sudoku.mlb     public basis
examples/
  demo.sml       parse / solve / uniqueness walkthrough
test/
  harness.sml    shared assertion harness
  test.sml       canonical puzzle vectors (31 checks)
  entry.sml / main.sml
tools/polybuild  Poly/ML build wrapper
```

## Tests

31 deterministic checks. Three canonical puzzles with **known unique
solutions** — the Wikipedia easy example, Arto Inkala's 2012 "world's hardest"
Sudoku, and a 17-clue minimal puzzle — are each asserted to solve to their exact
solution string and to have exactly one solution (`countSolutions … 2 = 1`). An
over-constrained (but duplicate-free) board is asserted to return `NONE`/`0`,
and `isValid` is checked to reject row, column and box duplicates. Parsing,
rendering, `set` persistence, and `candidates` are also covered. Run
`make all-tests` to verify identical output under both compilers.

## License

MIT. See [LICENSE](LICENSE).
