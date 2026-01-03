#!/bin/bash

# Import Yellow Taxi Trip Data into Docker Container

set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-nyc-taxi-postgres}"
DB_NAME="${POSTGRES_DB:-nyc-taxi-data}"
DB_USER="${POSTGRES_USER:-postgres}"

year_month_regex="tripdata_([0-9]{4})-([0-9]{2})"

yellow_schema="(vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, rate_code_id, store_and_fwd_flag, pickup_location_id, dropoff_location_id, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount, congestion_surcharge, airport_fee)"

yellow_schema_pre_2011="(vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, pickup_longitude, pickup_latitude, rate_code_id, store_and_fwd_flag, dropoff_longitude, dropoff_latitude, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, total_amount)"

# Function to run psql in container
run_psql() {
    docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} "$@"
}

echo "=== Importing Yellow Taxi Trip Data ==="

for parquet_filename in data/yellow_tripdata*.parquet; do
  if [ ! -f "$parquet_filename" ]; then
    echo "No yellow taxi parquet files found"
    continue
  fi

  [[ $parquet_filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}

  if [ $year -lt 2011 ]; then
    schema=$yellow_schema_pre_2011
  else
    schema=$yellow_schema
  fi

  echo "$(date): converting ${parquet_filename} to csv"
  python3 ./setup_files/convert_parquet_to_csv.py ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | run_psql -c "COPY yellow_tripdata_staging ${schema} FROM stdin CSV HEADER;"
  echo "$(date): finished raw load for ${csv_filename}"

  cat setup_files/populate_yellow_trips.sql | run_psql
  echo "$(date): loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "$(date): deleted ${csv_filename}"
done

echo "=== Yellow Taxi Import Complete ==="
