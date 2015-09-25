module Data.CQRS.Test.Internal.Utils
    ( chunkRandomly
    , chunkSized
    , chooseRandom
    , randomByteString
    ) where

import           Control.Monad.IO.Class (liftIO)
import           Control.Monad (replicateM)
import           Data.ByteString (ByteString)
import qualified Data.ByteString as B
import           Data.List (sort)
import           System.Random (randomR, randomRIO, getStdRandom, random)

-- Chunk a list randomly into 'n' chunks. Order of the elements is
-- preserved.
chunkRandomly :: Int -> [a] -> IO [[a]]
chunkRandomly n xs = do
    let lengthXs = length xs
    splitIndices <- fmap sort $ replicateM (n - 1) $ getStdRandom $ randomR (0, lengthXs - 1)
    return $ map chunk $ pairs $ [0] ++ splitIndices ++ [lengthXs]
  where
    pairs is = zip is (tail is)
    chunk (i, j) = take (j - i) $ drop i xs

-- Chunk a list into pieces of given average size (uniformly
-- distributed).
chunkSized :: Int -> [a] -> IO [[a]]
chunkSized avgSize xs = do
  n <- liftIO $ getStdRandom $ randomR (0, (length xs - 1) `div` avgSize)
  liftIO $ chunkRandomly n xs

-- Generate a random byte string of the given length.
randomByteString :: Int -> IO ByteString
randomByteString n = do
  -- Let's just generate 8 byte of random contents for each event.
  w8 <- replicateM n $ getStdRandom random
  return $ B.pack w8

-- Choose a random element from list.
chooseRandom :: [a] -> IO a
chooseRandom xs = do
  i <- randomRIO (0, length xs - 1)
  return $ xs !! i