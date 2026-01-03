#!/bin/bash

# Import FHVHV (Uber, Lyft, etc.) Trip Data into Docker Container

set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-nyc-taxi-postgres}"
DB_NAME="${POSTGRES_DB:-nyc-taxi-data}"
DB_USER="${POSTGRES_USER:-postgres}"

fhvhv_schema="(hvfhs_license_num, dispatching_base_num, originating_base_num, request_datetime, on_scene_datetime, pickup_datetime, dropoff_datetime, pickup_location_id, dropoff_location_id, trip_miles, trip_time, base_passenger_fare, tolls, black_car_fund, sales_tax, congestion_surcharge, airport_fee, tips, driver_pay, shared_request_flag, shared_match_flag, access_a_ride_flag, wav_request_flag, wav_match_flag)"

# Function to run psql in container
run_psql() {
    docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} "$@"
}

echo "=== Importing FHVHV Trip Data (Uber, Lyft, etc.) ==="

for parquet_filename in data/fhvhv_tripdata*.parquet; do
  if [ ! -f "$parquet_filename" ]; then
    echo "No FHVHV parquet files found"
    continue
  fi

  echo "$(date): converting ${parquet_filename} to csv"
  python3 ./setup_files/convert_parquet_to_csv.py ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | run_psql -c "COPY fhv_trips_staging ${fhvhv_schema} FROM stdin CSV HEADER;"
  echo "$(date): finished raw load for ${csv_filename}"

  cat setup_files/populate_fhv_trips.sql | run_psql
  echo "$(date): loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "$(date): deleted ${csv_filename}"
done

echo "=== FHVHV Trip Import Complete ==="
