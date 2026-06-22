(* sudoku.sig

   A self-contained, dependency-free 9x9 Sudoku model and deterministic
   constraint solver in pure Standard ML.

   The solver combines candidate elimination over rows / columns / boxes with
   backtracking guided by the minimum-remaining-values (MRV) heuristic. Cell and
   value ordering are fully deterministic (lowest index on an MRV tie, ascending
   candidate values), so a given puzzle always yields the SAME solution under
   both MLton and Poly/ML. No FFI, threads, clock, or randomness.

   Boards are 9x9. Cells hold 1..9, or 0 for blank. Rows and columns are 0-based;
   `(r, c)` addresses row `r`, column `c`. A board is parsed from an 81-character
   string where '.' or '0' denote a blank and '1'..'9' a given clue. *)

signature SUDOKU =
sig
  type board

  val size : int                 (* 9: side length *)
  val boxSize : int              (* 3: box side length *)

  (* ---- construction / rendering ---- *)
  val empty     : board                       (* all-blank board *)
  val fromString : string -> board option     (* 81 chars; NONE if malformed *)
  val toString  : board -> string             (* 81 chars, '.' for blank *)
  val pretty    : board -> string             (* human-readable grid *)

  (* ---- access ---- *)
  val get   : board -> int -> int -> int      (* value at (r, c) *)
  val set   : board -> int -> int -> int -> board  (* (r, c) := v (persistent) *)
  val clues : board -> int                    (* count of filled cells *)
  val candidates : board -> int -> int -> int list (* legal values at a blank *)

  (* ---- validity ---- *)
  val isValid    : board -> bool   (* no duplicate digit in any row/col/box *)
  val isComplete : board -> bool   (* no blanks and valid *)

  (* ---- solving ---- *)
  val solve : board -> board option
  (* Count solutions, stopping once `cap` have been found (cap >= 0). Use
     cap = 2 to test uniqueness (result of 1 means the unique solution). *)
  val countSolutions : board -> int -> int
  (* Up to `cap` distinct solutions, in the deterministic search order. *)
  val solveAll : board -> int -> board list
end
