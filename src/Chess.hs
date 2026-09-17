module Chess where

import Data.Array
import Data.Char (toUpper, intToDigit, digitToInt, ord, isDigit)
import Data.List (intercalate)
import Text.Read (readMaybe)

data Color = White | Black
    deriving (Eq, Ord, Show, Enum, Bounded)

data PieceType = Pawn | Knight | Bishop | Rook | Queen | King
    deriving (Eq, Ord, Show, Enum, Bounded)

data Piece = Piece {
    pieceColor :: !Color,
    pieceType :: !PieceType
}
    deriving (Eq, Show)

newtype Square = Square Int
    deriving (Eq, Ord, Show, Ix)

mkSquare :: Int -> Int -> Square
mkSquare rank file = Square (rank * 8 + file)

fileOf :: Square -> Int
fileOf (Square x) = x `mod` 8

rankOf :: Square -> Int
rankOf (Square x) = x `div` 8

opponent :: Color -> Color
opponent White = Black
opponent Black = White

isSlider :: PieceType -> Bool
isSlider pt = elem pt [Bishop, Rook, Queen]

data CastlingRights = CastlingRights {
    whiteKingside :: !Bool,
    whiteQueenside :: !Bool,
    blackKingside :: !Bool,
    blackQueenside :: !Bool
}
    deriving (Eq, Show)

noCastling :: CastlingRights
noCastling = CastlingRights {
    whiteKingside = False,
    whiteQueenside = False,
    blackKingside = False,
    blackQueenside = False
}

type Board = Array Square (Maybe Piece)

emptyBoard :: Board
emptyBoard = listArray (Square 0, Square 63) (replicate 64 Nothing)

data Position = Position {
    positionBoard :: !Board,
    sideToMove :: !Color,
    castling :: !CastlingRights,
    enPassant :: !(Maybe Square),
    halfmoveClock :: !Int,
    fullmoveNumber :: !Int
}
    deriving (Eq, Show)

pieceTypeChar :: PieceType -> Char
pieceTypeChar pt = case pt of
    Pawn -> 'p'
    Knight -> 'n'
    Bishop -> 'b'
    Rook -> 'r'
    Queen -> 'q'
    King -> 'k'

pieceChar :: Piece -> Char
pieceChar (Piece White pt) = toUpper $ pieceTypeChar pt
pieceChar (Piece Black pt) = pieceTypeChar pt

renderRank :: Board -> Int -> String
renderRank arr r = go 0 [arr ! mkSquare r f | f <- [0..7]]
    where
        flushEmpty n = if n == 0 then "" else [intToDigit n]
        go :: Int -> [Maybe Piece] -> String
        go n [] = flushEmpty n
        go n (Nothing : rest) = go (n + 1) rest
        go n (Just p : rest) = flushEmpty n ++ pieceChar p : (go 0 rest)

renderBoard :: Board -> String
renderBoard arr = intercalate "/" [renderRank arr r | r <- [7,6..0]]

colorString :: Color -> String
colorString White = "w"
colorString Black = "b"

renderCastling :: CastlingRights -> String
renderCastling (CastlingRights wk wq bk bq) =
    format r
    where
        a = if wk then "K" else ""
        b = if wq then "Q" else ""
        c = if bk then "k" else ""
        d = if bq then "q" else ""
        r = concat [a,b,c,d]
        format x = if x == "" then "-" else x

squareName :: Square -> String
squareName square = letters !! (fileOf square) : [intToDigit (rankOf square + 1)]
    where
        letters = ['a'..'z']

renderEnPassant :: Maybe Square -> String
renderEnPassant Nothing = "-"
renderEnPassant (Just square) = squareName square 

renderFEN :: Position -> String
renderFEN (Position positionBoard sideToMove castling enPassant halfmoveClock fullmoveNumber) =
    unwords [renderBoard positionBoard, colorString sideToMove, renderCastling castling, renderEnPassant enPassant, show halfmoveClock, show fullmoveNumber]

parseColor :: String -> Either String Color
parseColor s
    | s == "w" = Right White
    | s == "b" = Right Black
    | otherwise = Left $ "Cannot parse color (" ++ s ++ ")"

parseInt :: String -> Either String Int
parseInt s = case readMaybe s of
    Nothing -> Left $ "Invalid Int (" ++ s ++ ")"
    (Just x) -> Right x

parseEnPassant :: String -> Either String (Maybe Square)
parseEnPassant "-" = Right Nothing
parseEnPassant s@[a, b]
    | elem a ['a'..'h'] && isDigit b && elem (digitToInt b) [1..8] = Right $ Just $ mkSquare (digitToInt b - 1) (ord a - ord 'a')
    | otherwise = Left $ "Cannot parse en passant (" ++ s ++ ")"
parseEnPassant s = Left $ "Cannot parse en passant (" ++ s ++ ")"

parseCastling :: String -> Either String CastlingRights
parseCastling "-" = Right noCastling
parseCastling s
    | all (`elem` "QKqk") s = Right $ CastlingRights (elem 'K' s) (elem 'Q' s) (elem 'k' s) (elem 'q' s)
    | otherwise = Left $ "Cannot parse castling (" ++ s ++ ")"

splitOn :: Char -> String -> [String]
splitOn sep s = case break (== sep) s of
    (chunk, []) -> [chunk]
    (chunk, _:rest) -> chunk : splitOn sep rest

charPiece :: Char -> Maybe Piece
charPiece 'p' = Just (Piece Black Pawn)
charPiece 'n' = Just (Piece Black Knight)
charPiece 'b' = Just (Piece Black Bishop)
charPiece 'r' = Just (Piece Black Rook)
charPiece 'q' = Just (Piece Black Queen)
charPiece 'k' = Just (Piece Black King)
charPiece 'P' = Just (Piece White Pawn)
charPiece 'N' = Just (Piece White Knight)
charPiece 'B' = Just (Piece White Bishop)
charPiece 'R' = Just (Piece White Rook)
charPiece 'Q' = Just (Piece White Queen)
charPiece 'K' = Just (Piece White King)
charPiece _ = Nothing

parseRank :: Int -> String -> Either String [(Square, Maybe Piece)]
parseRank rank line = go 0 line
    where
        go file []
            | file == 8 = Right []
            | otherwise = Left ("rank has wrong width " ++ line)
        go file (c : rest)
            | file > 7 = Left ("Invalid representation for rank")
            | isDigit c = go (file + digitToInt c) rest
            | otherwise = case charPiece c of
                Nothing -> Left ("bad piece char: " ++ [c])
                Just p -> do
                    rest' <- go (file + 1) rest
                    pure ((mkSquare rank file, Just p) : rest')

parseBoard :: String -> Either String Board
parseBoard s = case splitOn '/' s of
    ranks
        | length ranks == 8 -> do
            pairss <- traverse (uncurry parseRank) (zip [7,6..0] ranks)
            pure (emptyBoard // concat pairss)
        | otherwise -> Left ("board must have 8 ranks: " ++ s)

parseFEN :: String -> Either String Position
parseFEN input = case words input of
    [b, c, cas, ep, hc, fm] -> do
        b' <- parseBoard b
        c' <- parseColor c
        cas' <- parseCastling cas
        ep' <- parseEnPassant ep
        hc' <- parseInt hc
        fm' <- parseInt fm
        pure (Position b' c' cas' ep' hc' fm')
    ws -> Left ("FEN needs 6 fields, got " ++ show (length ws))

startingPosition :: Position
startingPosition =
    case parseFEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" of
        Right p -> p
        Left e -> error ("bad starting FEN " ++ e)

data Move = Move {
    moveFrom :: !Square,
    moveTo :: !Square,
    movePromotion :: !(Maybe PieceType)
}
    deriving (Eq, Show)

pieceAt :: Position -> Square -> Maybe Piece
pieceAt position square = positionBoard position ! square

onBoard :: Int -> Int -> Bool
onBoard rank file = elem rank [0..7] && elem file [0..7]

validLanding :: Position -> Color -> Int -> Int -> Bool
validLanding position color r f
    | not (onBoard r f) = False
    | otherwise = case pieceAt position (mkSquare r f) of
        Nothing -> True
        (Just piece) -> pieceColor piece /= color


knightMoves :: Position -> Square -> [Move]
knightMoves position square = case pieceAt position square of
    Just piece | pieceType piece == Knight -> knightMovesFrom position (pieceColor piece) square
    _ -> []

knightMovesFrom :: Position -> Color -> Square -> [Move]
knightMovesFrom position color square = fmap toMove (filter landable (fmap offset knightDirections))
    where
        rank = rankOf square
        file = fileOf square
        knightDirections = [(-2, 1), (-2, -1), (2, 1), (2, -1), (1, 2), (1, -2), (-1, 2), (-1, -2)]
        offset (dr, df) = (rank + dr, file + df)
        landable (r, f) = validLanding position color r f
        toMove (r, f) = Move square (mkSquare r f) Nothing