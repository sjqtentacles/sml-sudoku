(* demo.sml - parse a puzzle, show it, solve it, and report clue count and
   solution uniqueness. Deterministic: identical output on every run and both
   compilers. *)

val puzzle = "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"

val () = print "Puzzle (the Wikipedia example):\n\n"
val () =
  case Sudoku.fromString puzzle of
    NONE => print "  (failed to parse)\n"
  | SOME b =>
      (print (Sudoku.pretty b);
       print ("\nclues: " ^ Int.toString (Sudoku.clues b) ^ "\n");
       print ("solutions (cap 2): " ^ Int.toString (Sudoku.countSolutions b 2)
              ^ "  (1 = unique)\n");
       case Sudoku.solve b of
         NONE => print "\nno solution\n"
       | SOME sol =>
           (print "\nSolution:\n\n";
            print (Sudoku.pretty sol);
            print ("\nas string: " ^ Sudoku.toString sol ^ "\n")))
