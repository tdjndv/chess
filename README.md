# chess

A chess engine written in Haskell, built from scratch.

## Status

Early. Board representation and FEN are working; move generation is in progress.

- [x] Core types — `Color`, `PieceType`, `Piece`, `Square`, `CastlingRights`, `Position`
- [x] FEN rendering
- [x] FEN parsing
- [ ] Move generation
  - [x] Knights
  - [ ] King
  - [ ] Sliders (bishop, rook, queen)
  - [ ] Pawns — pushes, double pushes, captures, en passant, promotion
  - [ ] Castling
  - [ ] Legality filtering (can't leave your own king in check)
- [ ] Perft validation
- [ ] Evaluation
- [ ] Search — negamax, alpha-beta, iterative deepening, quiescence
- [ ] Parallelism and concurrency

## Building

Requires GHC 9.6+ and cabal, both installed via [GHCup](https://www.haskell.org/ghcup/).

```bash
cabal build
cabal run chess
cabal repl        # loads the Chess module for poking at things
```

## Design notes

**Board representation is a mailbox array** — `Array Square (Maybe Piece)`, indexed by
`newtype Square = Square Int` where 0 is a1 and 63 is h8.

Chosen over bitboards for simplicity in a first implementation. Copying the whole array on
every update via `//` is slow, and the intention is to revisit this once perft is passing.
The flat `Int` index is deliberate: it's what a bitboard representation indexes by, so the
transition doesn't require reworking the square type.

**Parsing returns `Either String a`,** which gives malformed FEN a soft landing with a
message naming the offending input. The one exception is `startingPosition`, which calls
`error` — that FEN is hardcoded, so a failure there is a source bug rather than a runtime
condition.

**Every record field is strict.** A lazy field in a `Position` holds a thunk that keeps the
previous position alive; a few million of those during search is a significant space
problem. Strictness also makes the eventual move to parallel search tractable, since forcing
is already explicit.

**Move generation is piece-first, not side-first.** `knightMoves` generates moves for
whatever knight sits on the given square, regardless of whose turn it is. Filtering by side
to move happens at the caller. This keeps the same functions usable for attack detection,
which needs to ask about the opponent's pieces.

## Testing

No test suite yet. The next milestone that needs one is perft — counting leaf nodes at
depth N from known positions and comparing against published values. That's the only
reliable way to find move generation bugs; a search built on a buggy generator produces
plausible-looking nonsense.

Until then, checks are run by hand in `cabal repl`:

```haskell
-- FEN round-trip
fmap renderFEN (parseFEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

-- Knight on b1 at the start: two moves, a3 and c3
knightMoves startingPosition (Square 1)
```

## Layout

```
src/Chess.hs     everything, for now
app/Main.hs      executable stub
chess.cabal
```

Single module while the types are still moving. The natural split, when it comes, is
`Chess.Types` / `Chess.FEN` / `Chess.MoveGen` / `Chess.Eval` / `Chess.Search` / `Chess.UCI`,
with types at the bottom and no upward dependencies.

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 Tengda Jiang