#!/bin/sh
set -e

echo "Running database migrations..."
/app/bin/ticket_splitter eval "TicketSplitter.Release.migrate()"

echo "Starting Phoenix server..."
exec /app/bin/ticket_splitter start
