{-# LANGUAGE OverloadedStrings #-}
module Data.CQRS.PostgreSQL.Internal.EventStream
    ( newEventStream
    ) where

import           Control.Monad.IO.Class (liftIO)
import           Data.ByteString (ByteString)
import           Data.Pool (Pool)
import           Data.CQRS.Internal.StreamPosition
import           Data.CQRS.Types.PersistedEvent
import           Data.CQRS.Types.EventStream
import           Data.CQRS.PostgreSQL.Internal.Query
import           Data.CQRS.PostgreSQL.Internal.Identifiers
import           Data.CQRS.PostgreSQL.Internal.Transaction
import           Database.Peregrin.Metadata
import           Database.PostgreSQL.Simple (Connection)
import           System.IO.Streams (InputStream)
import qualified System.IO.Streams.Combinators as SC

readEventStream :: Pool Connection -> Identifiers -> StreamPosition -> (InputStream (StreamPosition, PersistedEvent' ByteString ByteString) -> IO a) -> IO a
readEventStream connectionPool identifiers (StreamPosition sp0) f =
  runTransactionP connectionPool $
    query sqlReadEvents (eventTable, sp0) $ \is ->
      liftIO (SC.map unpack is) >>= (liftIO . f)
  where
    -- Unpack result columns
    unpack (lTimestamp, aggregateId, eventData, sequenceNumber, timestampMillis) =
        (StreamPosition lTimestamp, PersistedEvent' aggregateId (PersistedEvent eventData sequenceNumber timestampMillis))
    -- SQL
    eventTable = tblEvent identifiers

    sqlReadEvents =
      "   SELECT \"l_timestamp\", \"aggregate_id\", \"event_data\", \"seq_no\", \"timestamp\" \
      \     FROM ? \
      \    WHERE \"l_timestamp\" > ? \
      \ ORDER BY \"l_timestamp\" ASC"

newEventStream :: Pool Connection -> Schema -> IO (EventStream ByteString ByteString)
newEventStream connectionPool schema =
  return EventStream
    { esReadEventStream = readEventStream connectionPool identifiers
    }
  where
    identifiers = mkIdentifiers schema
