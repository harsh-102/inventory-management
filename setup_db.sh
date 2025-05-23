#!/bin/bash

# Check if DATABASE_URL is provided
if [ -z "$1" ]; then
    echo "Please provide the DATABASE_URL from Render"
    echo "Usage: ./setup_db.sh 'postgres://user:password@host:port/database'"
    exit 1
fi

# Run the SQL script
echo "Setting up database..."
psql "$1" -f setup_database_postgres.sql

# Check if the command was successful
if [ $? -eq 0 ]; then
    echo "Database setup completed successfully!"
else
    echo "Error setting up database. Please check the error message above."
fi 