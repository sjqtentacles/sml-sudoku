(* sudoku.sml

   Implementation of SUDOKU: a 9x9 board over an immutable int vector and a
   deterministic constraint-propagation + MRV backtracking solver. Bit ops on
   candidate sets go through Word (bit v set <=> digit v is taken). *)

structure Sudoku :> SUDOKU =
struct
  val size = 9
  val boxSize = 3
  val ncells = 81

  (* immutable, length 81; 0 = blank, 1..9 = digit *)
  type board = int vector

  val empty : board = Vector.tabulate (ncells, fn _ => 0)

  fun idx (r, c) = r * size + c
  fun get b r c = Vector.sub (b, idx (r, c))
  fun set b r c v = Vector.update (b, idx (r, c), v)

  fun clues b = Vector.foldl (fn (v, n) => if v <> 0 then n + 1 else n) 0 b

  (* ---- parsing / rendering ---- *)
  fun fromString s =
    if String.size s <> ncells then NONE
    else
      let
        fun cell ch =
          if ch = #"." orelse ch = #"0" then SOME 0
          else if Char.isDigit ch then SOME (Char.ord ch - Char.ord #"0")
          else NONE
        val cells = List.map cell (String.explode s)
      in
        if List.exists (fn x => x = NONE) cells then NONE
        else SOME (Vector.fromList (List.map valOf cells))
      end

  fun toString b =
    String.implode
      (List.tabulate
         (ncells,
          fn i => let val v = Vector.sub (b, i)
                  in if v = 0 then #"." else Char.chr (Char.ord #"0" + v) end))

  fun pretty b =
    let
      fun cellStr v = if v = 0 then "." else Int.toString v
      fun rowStr r =
        let
          fun grp lo =
            String.concatWith " " (List.tabulate (3, fn k => cellStr (get b r (lo + k))))
        in
          grp 0 ^ " | " ^ grp 3 ^ " | " ^ grp 6
        end
      val sep = "------+-------+------"
      val rows =
        List.tabulate
          (size,
           fn r => rowStr r ^ (if r = 2 orelse r = 5 then "\n" ^ sep else ""))
    in
      String.concatWith "\n" rows ^ "\n"
    end

  (* ---- candidate bitsets via Word ---- *)
  val fullMask : word = 0wx3FE  (* bits 1..9 set *)
  fun bitOf v = Word.<< (0w1, Word.fromInt v)
  fun isSet (m, v) = Word.andb (m, bitOf v) <> 0w0

  fun popcount w =
    let
      fun go (w, n) =
        if w = 0w0 then n
        else go (Word.>> (w, 0w1), n + Word.toInt (Word.andb (w, 0w1)))
    in go (w, 0) end

  (* used-digit mask for the row, column and box containing (r, c) *)
  fun usedMask (arr, r, c) =
    let
      val m = ref 0w0
      fun add v = if v <> 0 then m := Word.orb (!m, bitOf v) else ()
      val () = List.app (fn j => add (Array.sub (arr, r * size + j)))
                        (List.tabulate (size, fn j => j))
      val () = List.app (fn i => add (Array.sub (arr, i * size + c)))
                        (List.tabulate (size, fn i => i))
      val br = (r div boxSize) * boxSize
      val bc = (c div boxSize) * boxSize
      val () =
        List.app
          (fn k =>
             let val rr = br + k div boxSize
                 val cc = bc + k mod boxSize
             in add (Array.sub (arr, rr * size + cc)) end)
          (List.tabulate (size, fn k => k))
    in !m end

  fun candMask (arr, i) =
    Word.andb (Word.notb (usedMask (arr, i div size, i mod size)), fullMask)

  fun candidates b r c =
    if get b r c <> 0 then []
    else
      let
        val arr = Array.tabulate (ncells, fn i => Vector.sub (b, i))
        val m = candMask (arr, idx (r, c))
      in
        List.filter (fn v => isSet (m, v)) (List.tabulate (size, fn k => k + 1))
      end

  (* ---- validity ---- *)
  fun groupOk get1 =
    let
      fun go (k, seen) =
        if k >= size then true
        else
          let val v = get1 k
          in
            if v = 0 then go (k + 1, seen)
            else if isSet (seen, v) then false
            else go (k + 1, Word.orb (seen, bitOf v))
          end
    in go (0, 0w0) end

  fun isValid b =
    let
      fun rowOk r = groupOk (fn c => get b r c)
      fun colOk c = groupOk (fn r => get b r c)
      fun boxOk bx =
        let val br = (bx div boxSize) * boxSize
            val bc = (bx mod boxSize) * boxSize
        in groupOk (fn k => get b (br + k div boxSize) (bc + k mod boxSize)) end
      fun all f = List.all f (List.tabulate (size, fn i => i))
    in
      all rowOk andalso all colOk andalso all boxOk
    end

  fun isComplete b = clues b = ncells andalso isValid b

  (* ---- MRV selection ---- *)
  (* returns SOME (index, mask) of the empty cell with fewest candidates
     (lowest index breaks ties); NONE if no empty cell remains *)
  fun selectMRV arr =
    let
      fun go (i, best) =
        if i >= ncells then best
        else if Array.sub (arr, i) <> 0 then go (i + 1, best)
        else
          let
            val m = candMask (arr, i)
            val cnt = popcount m
            val best' =
              case best of
                NONE => SOME (i, m, cnt)
              | SOME (_, _, bc) => if cnt < bc then SOME (i, m, cnt) else best
          in
            if cnt = 0 then SOME (i, m, 0)  (* dead end: stop early *)
            else go (i + 1, best')
          end
    in
      case go (0, NONE) of
        NONE => NONE
      | SOME (i, m, _) => SOME (i, m)
    end

  (* fill solution into arr in place; returns true on success *)
  fun solveInPlace arr =
    case selectMRV arr of
      NONE => true
    | SOME (i, mask) =>
        if mask = 0w0 then false
        else
          let
            fun loop v =
              if v > size then false
              else if isSet (mask, v) then
                (Array.update (arr, i, v);
                 if solveInPlace arr then true
                 else (Array.update (arr, i, 0); loop (v + 1)))
              else loop (v + 1)
          in loop 1 end

  fun toArray b = Array.tabulate (ncells, fn i => Vector.sub (b, i))
  fun freeze arr = Vector.tabulate (ncells, fn i => Array.sub (arr, i))

  fun solve b =
    if not (isValid b) then NONE
    else
      let val arr = toArray b
      in if solveInPlace arr then SOME (freeze arr) else NONE end

  (* count up to cap solutions *)
  fun countSolutions b cap =
    if cap <= 0 orelse not (isValid b) then 0
    else
      let
        val arr = toArray b
        (* count solutions, but never more than `remaining` (bounds the search) *)
        fun go remaining =
          if remaining <= 0 then 0
          else
            case selectMRV arr of
              NONE => 1
            | SOME (i, mask) =>
                if mask = 0w0 then 0
                else
                  let
                    fun loop (v, acc) =
                      if v > size orelse acc >= remaining then acc
                      else if isSet (mask, v) then
                        let
                          val () = Array.update (arr, i, v)
                          val sub = go (remaining - acc)
                          val () = Array.update (arr, i, 0)
                        in loop (v + 1, acc + sub) end
                      else loop (v + 1, acc)
                  in loop (1, 0) end
      in go cap end

  fun solveAll b cap =
    if cap <= 0 orelse not (isValid b) then []
    else
      let
        val arr = toArray b
        val acc = ref ([] : board list)
        val n = ref 0
        fun go () =
          if !n >= cap then ()
          else
            case selectMRV arr of
              NONE => (acc := freeze arr :: !acc; n := !n + 1)
            | SOME (i, mask) =>
                if mask = 0w0 then ()
                else
                  let
                    fun loop v =
                      if v > size orelse !n >= cap then ()
                      else
                        (if isSet (mask, v) then
                           (Array.update (arr, i, v); go ();
                            Array.update (arr, i, 0))
                         else ();
                         loop (v + 1))
                  in loop 1 end
      in go (); List.rev (!acc) end
end
