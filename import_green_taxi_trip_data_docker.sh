#!/bin/bash

# Import Green Taxi Trip Data into Docker Container

set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-nyc-taxi-postgres}"
DB_NAME="${POSTGRES_DB:-nyc-taxi-data}"
DB_USER="${POSTGRES_USER:-postgres}"

green_schema="(vendor_id, lpep_pickup_datetime, lpep_dropoff_datetime, store_and_fwd_flag, rate_code_id, pickup_location_id, dropoff_location_id, passenger_count, trip_distance, fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee, improvement_surcharge, total_amount, payment_type, trip_type, congestion_surcharge)"

# Function to run psql in container
run_psql() {
    docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} "$@"
}

echo "=== Importing Green Taxi Trip Data ==="

for parquet_filename in data/green_tripdata*.parquet; do
  if [ ! -f "$parquet_filename" ]; then
    echo "No green taxi parquet files found"
    continue
  fi

  echo "$(date): converting ${parquet_filename} to csv"
  python3 ./setup_files/convert_parquet_to_csv.py ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | run_psql -c "COPY green_tripdata_staging ${green_schema} FROM stdin CSV HEADER;"
  echo "$(date): finished raw load for ${csv_filename}"

  cat setup_files/populate_green_trips.sql | run_psql
  echo "$(date): loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "$(date): deleted ${csv_filename}"
done

echo "=== Green Taxi Import Complete ==="
