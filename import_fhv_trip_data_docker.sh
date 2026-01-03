#!/bin/bash

# Import FHV Trip Data into Docker Container

set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-nyc-taxi-postgres}"
DB_NAME="${POSTGRES_DB:-nyc-taxi-data}"
DB_USER="${POSTGRES_USER:-postgres}"

fhv_schema="(dispatching_base_num, pickup_datetime, dropoff_datetime, pickup_location_id, dropoff_location_id, legacy_shared_ride_flag, affiliated_base_num)"

# Function to run psql in container
run_psql() {
    docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} "$@"
}

echo "=== Importing FHV Trip Data ==="

for parquet_filename in data/fhv_tripdata*.parquet; do
  if [ ! -f "$parquet_filename" ]; then
    echo "No FHV parquet files found"
    continue
  fi

  echo "$(date): converting ${parquet_filename} to csv"
  python3 ./setup_files/convert_parquet_to_csv.py ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | run_psql -c "COPY fhv_trips_staging ${fhv_schema} FROM stdin CSV HEADER;"
  echo "$(date): finished raw load for ${csv_filename}"

  cat setup_files/populate_fhv_trips.sql | run_psql
  echo "$(date): loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "$(date): deleted ${csv_filename}"
done

echo "=== FHV Trip Import Complete ==="
