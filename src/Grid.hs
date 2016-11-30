{-# LANGUAGE OverloadedStrings #-}

module Grid where

import           Control.Applicative
import           Data.List.Split
import           Data.Map            (Map, fromList)
import qualified Data.Map            as Map
import qualified Data.Text           as T
import           Debug.Trace
import           Disc
import           Graphics.Blank

-- | Coordinate system goes from -4 to 3
type Cord = (Int, Int)
minX :: Int
minX = -4

maxX :: Int
maxX = 3

minY :: Int
minY = -4

maxY :: Int
maxY = 3

type Board = Map Cord Disc

-- | Orientation of the line
-- whether it is North, south east, west, south-east, etc
-- The order is important as it matches with the adjacent square list
data Direction = NW | N | NE | E | SE | S | SW | W
  deriving (Show, Eq, Enum)

grid w h = do
        let sz = min w h
        let sqSize = sz / 9
        clearRect (0,0,w,h)
        beginPath()
        save()
        translate (w / 2, h / 2)
        lineWidth 3
        beginPath()
        strokeStyle "black"
        sequence_ $ computeSquare (-sz/2, -sz/2) sqSize <$> gridCord 8
        fillStyle "green"
        fill()
        stroke()
        restore()

gridCord n = [(x,y) | x <- [0..n-1], y <- [0..n-1]]

computeSquare (x0, y0) sz (x, y) = sqr (x0 + x*sz, y0 + y * sz, sz)
sqr (x, y, s) = rect (x, y, s, s)

-- | Returns the square co-ordiantes of the click
pointToSq :: (Double, Double)  -> Double -> Double -> Maybe Cord
pointToSq (x,y) w h = validate $
  do x' <- Just $ round $ ((x - w / 2) / sz) * 10
     y' <- Just $ round $ ((y - h / 2) / sz) * 10
     return (x', y')
  where sz = min w h

-- | validate if the click in inside the board
validate :: Maybe Cord -> Maybe Cord
validate c@(Just (x , y)) = if (x > maxX || x < minX) || (y > maxY || y < minY)
  then Nothing else c
validate Nothing = Nothing

-- | return the adjacent co-ordinates starting from NE clockwise
adjacent :: Cord -> [Cord]
adjacent (x, y) = Prelude.filter (\(a,b) -> a >= minX && a <= maxX
                                   && b >= minY && b <= maxY && (a,b) /= (x,y))
  $ (,) <$> [ x-1..x+1 ] <*> [ y-1..y+1 ]

direction :: Cord -> Cord -> Direction
direction (nc_x, nc_y) (oc_x, oc_y)
  | (nc_x > oc_x) && (nc_y > oc_y) = NW
  | (nc_x == oc_x) && (nc_y > oc_y) = N
  | (nc_x < oc_x) && (nc_y > oc_y) = NE
  | (nc_x < oc_x) && (nc_y == oc_y) = E
  | (nc_x < oc_x) && (nc_y < oc_y) = SE
  | (nc_x == oc_x) && (nc_y < oc_y) = S
  | (nc_x > oc_x) && (nc_y < oc_y) = SW
  | (nc_x > oc_x) && (nc_y == oc_y) = W

-- | Gives the next co-ordinate in the given direction
moveInDirection :: Direction -> Cord -> Maybe Cord
moveInDirection N (x,y)  = validate $ return (x, y-1)
moveInDirection NE (x,y) = validate $ return (x+1,y-1)
moveInDirection E (x,y)  = validate $ return (x+1,y)
moveInDirection SE (x,y) = validate $ return (x+1,y+1)
moveInDirection S (x,y)  = validate $ return (x,y+1)
moveInDirection SW (x,y) = validate $ return (x-1,y+1)
moveInDirection W (x,y)  = validate $ return (x-1,y)
moveInDirection NW (x,y) = validate $ return (x-1,y-1)

-- | It is a valid move if
-- 1) The current pos is empty
-- 2) There is an adjacent square with opposite colored disc
-- 3) placing the disc creates a sandwich
isValidMove :: Cord -> Map Cord Disc -> Disc -> Bool
isValidMove pos board turn = isEmptySquare pos board
  && areAdjacentSquareOpposite pos board turn
  && sandwiches pos board turn

-- | Condition 1) in @isValidMove@
isEmptySquare :: Cord -> Map Cord Disc -> Bool
isEmptySquare pos board = (Map.lookup pos board) == Nothing

-- | Condition 2) in @isValidMove@
areAdjacentSquareOpposite :: Cord -> Map Cord Disc -> Disc -> Bool
areAdjacentSquareOpposite pos board turn = not . null
  $ adjacentOppositeSquares pos board turn

adjacentOppositeSquares :: Cord -> Map Cord Disc -> Disc -> [Maybe Disc]
adjacentOppositeSquares  pos board turn =
  filter (\e -> e /= Nothing && (e == (Just $ swap turn)))
  $ fmap ((flip Map.lookup) board)
  $ adjacent pos

-- | condition 3) in @isValidMove@
-- Select all adjacent squares that have opposite disc
-- For each of those discs get first disk of same color in appropriate direction
-- if any of such discs exist return True
-- else return False
sandwiches :: Cord -> Map Cord Disc -> Disc -> Bool
sandwiches pos board turn = not . null $ filter (/=Nothing)
  $  allFirstSameDiscs pos board turn

allFirstSameDiscs pos board turn = sds <$> vps
  where
    ds = (toEnum <$> [0..7::Int])::[Direction]
    l = \d -> moveInDirection d pos
    ps = zip ds (l <$> ds)
    vps = filter (\(a, Just b) -> (Map.lookup b board /= Just turn))
          $ filter (\(a, b) -> (b /= Nothing))
          $ (\(a, b) -> (a, validate b)) <$> ps
    sds = \(d, (Just p)) -> getFirstSameDisc p d board turn

-- | returns the co-ordinate of the first disc of the same color
-- that appears after 1 or more opposite colored discs
getFirstSameDisc :: Cord -> Direction -> Map Cord Disc -> Disc -> Maybe (Cord, Disc)
getFirstSameDisc pos dir board turn = collapse $ head z
  where
    -- get the series of all the coordinates in the given direction
    l = (Just pos)
        : scanl (\c _ -> c >>= moveInDirection dir)
                (Just pos >>= moveInDirection dir) l
    md = ((flip Map.lookup) board =<<) <$> l
    z =  dropWhile (\(a,b) -> (b == (Just $ swap turn)) && (b /= Nothing))
      $ safeTail
      $ zip l md

collapse :: (Maybe a, Maybe b) -> Maybe (a,b)
collapse ((Just x), (Just y)) = Just (x, y)
collapse _                    = Nothing

safeLast :: [a] -> Maybe a
safeLast []     = Nothing
safeLast (x:[]) = Just x
safeLast (x:xs) = safeLast xs

safeTail :: [a] -> [a]
safeTail []     = []
safeTail (x:xs) = xs

safeHead :: [a] -> Maybe a
safeHead []     = Nothing
safeHead (x:xs) = Just x

updateBoard :: Cord -> Disc -> Board -> Board
updateBoard pos turn board = Map.union (fromList nv) board
  where
    z :: [(Direction, Maybe (Cord, Disc))]
    z = zip ((toEnum <$> [0..7::Int])::[Direction]) $ allFirstSameDiscs pos board turn
    bs = sequence $ concat $ between pos board <$> z
    nv = case bs of
      Just l  ->  zip l $ repeat turn
      Nothing -> []

between :: Cord -> Board -> (Direction, Maybe (Cord, Disc)) -> [Maybe Cord]
between _ _ (_, Nothing)              = []
between pos1 board (_, Just (pos2, disc)) =
  takeWhile (\c -> c /= Just pos2 && c /= Nothing) l
  where
    l = (Just pos1)
        : scanl (\c _ -> c >>= moveInDirection d)
                (Just pos1 >>= moveInDirection d) l
    d = direction pos1 pos2
