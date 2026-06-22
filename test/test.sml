(* Tests for sml-sudoku.

   Canonical puzzles with KNOWN unique solutions:
     * easy  : the Wikipedia example puzzle.
     * hard  : Arto Inkala's 2012 "world's hardest" Sudoku.
     * c17   : a 17-clue minimal puzzle (the minimum possible clue count).
   We assert that `solve` reproduces the exact known solution string, that each
   puzzle has exactly one solution (countSolutions cap 2 = 1), that an
   over-constrained board has no solution, and that `isValid` rejects
   duplicates. All values are fixed, so output is identical on both compilers. *)

structure Tests =
struct
  open Harness

  val easy = "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"
  val easySol = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

  val hard = "800000000003600000070090200050007000000045700000100030001000068008500010090000400"
  val hardSol = "812753649943682175675491283154237896369845721287169534521974368438526917796318452"

  val c17 = "000000010400000000020000000000050407008000300001090000300400200050100000000806000"
  val c17Sol = "693784512487512936125963874932651487568247391741398625319475268856129743274836159"

  fun solveStr s =
    case Sudoku.fromString s of
      NONE => "PARSE-FAIL"
    | SOME b => (case Sudoku.solve b of NONE => "NO-SOLUTION" | SOME g => Sudoku.toString g)

  fun runAll () =
    let
      val () = section "parsing / rendering"
      val () = checkBool "fromString wrong length -> NONE"
                 (true, not (isSome (Sudoku.fromString "123")))
      val () = checkBool "fromString bad char -> NONE"
                 (true, not (isSome (Sudoku.fromString (CharVector.tabulate (81, fn i => if i = 0 then #"x" else #".")))))
      val () = checkBool "fromString easy ok" (true, isSome (Sudoku.fromString easy))
      val () =
        case Sudoku.fromString easy of
          NONE => check "easy parses" false
        | SOME b =>
            (checkString "toString round-trips (blanks as '.')" (easy, Sudoku.toString b);
             checkInt "clues counted" (30, Sudoku.clues b);
             checkInt "get (0,0)" (5, Sudoku.get b 0 0);
             checkInt "get (0,1)" (3, Sudoku.get b 0 1);
             checkInt "get (0,2) blank" (0, Sudoku.get b 0 2))

      val () = section "set is persistent"
      val () =
        case Sudoku.fromString easy of
          NONE => check "easy parses" false
        | SOME b =>
            let val b2 = Sudoku.set b 0 2 9
            in checkInt "set writes" (9, Sudoku.get b2 0 2);
               checkInt "original unchanged" (0, Sudoku.get b 0 2)
            end

      val () = section "candidates"
      val () =
        case Sudoku.fromString easy of
          NONE => check "easy parses" false
        | SOME b => checkIntList "candidates at (0,2)" ([1,2,4], Sudoku.candidates b 0 2)

      val () = section "solve: exact known solutions"
      val () = checkString "easy solves to known solution" (easySol, solveStr easy)
      val () = checkString "hard (Inkala) solves to known solution" (hardSol, solveStr hard)
      val () = checkString "c17 (17-clue) solves to known solution" (c17Sol, solveStr c17)

      val () = section "solved boards are complete & valid"
      val () =
        case Sudoku.fromString easySol of
          NONE => check "sol parses" false
        | SOME b => (checkBool "easy solution isComplete" (true, Sudoku.isComplete b);
                     checkBool "easy solution isValid" (true, Sudoku.isValid b))

      val () = section "uniqueness (countSolutions cap 2 = 1)"
      fun uniq s = case Sudoku.fromString s of SOME b => Sudoku.countSolutions b 2 | NONE => ~1
      val () = checkInt "easy unique" (1, uniq easy)
      val () = checkInt "hard unique" (1, uniq hard)
      val () = checkInt "c17 unique" (1, uniq c17)

      val () = section "solveAll returns the unique solution"
      val () =
        case Sudoku.fromString easy of
          NONE => check "easy parses" false
        | SOME b =>
            let val sols = Sudoku.solveAll b 5
            in checkInt "exactly one solution" (1, List.length sols);
               checkString "solution matches" (easySol, Sudoku.toString (hd sols))
            end

      val () = section "over-constrained board -> NONE / 0"
      (* row 0 = 1..8 with (0,8) blank needing 9, but col 8 already has a 9 *)
      val bad = "123456780" ^ "000000009" ^ String.implode (List.tabulate (63, fn _ => #"0"))
      val () =
        case Sudoku.fromString bad of
          NONE => check "bad parses" false
        | SOME b =>
            (checkBool "bad board is valid (no duplicate givens)" (true, Sudoku.isValid b);
             checkIntList "no candidate at forced cell (0,8)" ([], Sudoku.candidates b 0 8);
             checkBool "solve returns NONE" (true, not (isSome (Sudoku.solve b)));
             checkInt "countSolutions = 0" (0, Sudoku.countSolutions b 2))

      val () = section "isValid rejects duplicates"
      (* duplicate 5 in row 0 *)
      val dupRow = "55" ^ String.implode (List.tabulate (79, fn _ => #"."))
      val () =
        case Sudoku.fromString dupRow of
          NONE => check "dup parses" false
        | SOME b => checkBool "duplicate in row rejected" (false, Sudoku.isValid b)
      (* duplicate 7 in a column: (0,0)=7 and (1,0)=7 *)
      val dupCol = "7........" ^ "7" ^ String.implode (List.tabulate (71, fn _ => #"."))
      val () =
        case Sudoku.fromString dupCol of
          NONE => check "dupcol parses" false
        | SOME b => checkBool "duplicate in column rejected" (false, Sudoku.isValid b)
      (* duplicate 4 in top-left box: (0,0)=4 and (1,1)=4 *)
      val dupBox = "4........" ^ ".4......." ^ String.implode (List.tabulate (63, fn _ => #"."))
      val () =
        case Sudoku.fromString dupBox of
          NONE => check "dupbox parses" false
        | SOME b => checkBool "duplicate in box rejected" (false, Sudoku.isValid b)

      val () = section "empty board: countSolutions respects cap"
      val () = checkInt "empty board, cap 5 -> 5" (5, Sudoku.countSolutions Sudoku.empty 5)
      val () = checkInt "empty board is valid -> isValid" (1, if Sudoku.isValid Sudoku.empty then 1 else 0)
      val () = checkInt "empty solveAll cap 3 -> 3" (3, List.length (Sudoku.solveAll Sudoku.empty 3))
    in
      Harness.run ()
    end

  val run = runAll
end
