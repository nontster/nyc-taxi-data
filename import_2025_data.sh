#!/bin/bash

# Import only 2025 NYC Taxi Data into Docker Container
# All processing (parquet->csv conversion and import) happens inside the container

set -e

YEAR_FILTER="2025"

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-nyc-taxi-postgres}"
DB_NAME="${POSTGRES_DB:-nyc-taxi-data}"
DB_USER="${POSTGRES_USER:-postgres}"

# Function to run psql in container
run_psql() {
    docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} "$@"
}

# Function to convert parquet to csv in container
convert_parquet() {
    local parquet_file=$1
    docker exec ${CONTAINER_NAME} python3 /usr/local/bin/convert_parquet_to_csv.py /data/$(basename ${parquet_file})
}

echo "=============================================="
echo "Importing NYC Taxi Data for Year ${YEAR_FILTER}"
echo "Container: ${CONTAINER_NAME}"
echo "Database: ${DB_NAME}"
echo "=============================================="

# Wait for container to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; do
    sleep 2
done
echo "PostgreSQL is ready!"

# Schema definitions
yellow_schema="(vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, rate_code_id, store_and_fwd_flag, pickup_location_id, dropoff_location_id, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount, congestion_surcharge, airport_fee, cbd_congestion_fee)"

green_schema="(vendor_id, lpep_pickup_datetime, lpep_dropoff_datetime, store_and_fwd_flag, rate_code_id, pickup_location_id, dropoff_location_id, passenger_count, trip_distance, fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee, improvement_surcharge, total_amount, payment_type, trip_type, congestion_surcharge, cbd_congestion_fee)"

fhv_schema="(dispatching_base_num, pickup_datetime, dropoff_datetime, pickup_location_id, dropoff_location_id, sr_flag, affiliated_base_num)"

fhvhv_schema="(hvfhs_license_num, dispatching_base_num, originating_base_num, request_datetime, on_scene_datetime, pickup_datetime, dropoff_datetime, pickup_location_id, dropoff_location_id, trip_miles, trip_time, base_passenger_fare, tolls, bcf, sales_tax, congestion_surcharge, airport_fee, tips, driver_pay, shared_request_flag, shared_match_flag, access_a_ride_flag, wav_request_flag, wav_match_flag, cbd_congestion_fee)"

# Import Yellow Taxi Data
echo ""
echo "--- Importing Yellow Taxi Data ---"
for parquet_filename in data/yellow_tripdata_${YEAR_FILTER}*.parquet; do
  if [ -f "$parquet_filename" ]; then
    echo "$(date): converting ${parquet_filename} to csv (in container)"
    convert_parquet ${parquet_filename}

    csv_basename=$(basename ${parquet_filename/.parquet/.csv})
    docker exec ${CONTAINER_NAME} bash -c "cat /data/${csv_basename} | psql -U ${DB_USER} -d ${DB_NAME} -c \"COPY yellow_tripdata_staging ${yellow_schema} FROM stdin CSV HEADER;\""
    echo "$(date): finished raw load for ${csv_basename}"

    cat setup_files/populate_yellow_trips.sql | run_psql
    echo "$(date): loaded trips for ${csv_basename}"

    docker exec ${CONTAINER_NAME} rm -f /data/${csv_basename}
    echo "$(date): deleted ${csv_basename}"
  fi
done

# Import Green Taxi Data
echo ""
echo "--- Importing Green Taxi Data ---"
for parquet_filename in data/green_tripdata_${YEAR_FILTER}*.parquet; do
  if [ -f "$parquet_filename" ]; then
    echo "$(date): converting ${parquet_filename} to csv (in container)"
    convert_parquet ${parquet_filename}

    csv_basename=$(basename ${parquet_filename/.parquet/.csv})
    docker exec ${CONTAINER_NAME} bash -c "cat /data/${csv_basename} | psql -U ${DB_USER} -d ${DB_NAME} -c \"COPY green_tripdata_staging ${green_schema} FROM stdin CSV HEADER;\""
    echo "$(date): finished raw load for ${csv_basename}"

    cat setup_files/populate_green_trips.sql | run_psql
    echo "$(date): loaded trips for ${csv_basename}"

    docker exec ${CONTAINER_NAME} rm -f /data/${csv_basename}
    echo "$(date): deleted ${csv_basename}"
  fi
done

# Import FHV Data
echo ""
echo "--- Importing FHV Data ---"
for parquet_filename in data/fhv_tripdata_${YEAR_FILTER}*.parquet; do
  if [ -f "$parquet_filename" ]; then
    echo "$(date): converting ${parquet_filename} to csv (in container)"
    convert_parquet ${parquet_filename}

    csv_basename=$(basename ${parquet_filename/.parquet/.csv})
    docker exec ${CONTAINER_NAME} bash -c "cat /data/${csv_basename} | psql -U ${DB_USER} -d ${DB_NAME} -c \"COPY fhv_trips_staging ${fhv_schema} FROM stdin CSV HEADER;\""
    echo "$(date): finished raw load for ${csv_basename}"

    cat setup_files/populate_fhv_trips.sql | run_psql
    echo "$(date): loaded trips for ${csv_basename}"

    docker exec ${CONTAINER_NAME} rm -f /data/${csv_basename}
    echo "$(date): deleted ${csv_basename}"
  fi
done

# Import FHVHV Data (Uber, Lyft, etc.)
echo ""
echo "--- Importing FHVHV Data (Uber, Lyft, etc.) ---"
for parquet_filename in data/fhvhv_tripdata_${YEAR_FILTER}*.parquet; do
  if [ -f "$parquet_filename" ]; then
    echo "$(date): converting ${parquet_filename} to csv (in container)"
    convert_parquet ${parquet_filename}

    csv_basename=$(basename ${parquet_filename/.parquet/.csv})
    docker exec ${CONTAINER_NAME} bash -c "cat /data/${csv_basename} | psql -U ${DB_USER} -d ${DB_NAME} -c \"COPY fhv_trips_staging ${fhvhv_schema} FROM stdin CSV HEADER;\""
    echo "$(date): finished raw load for ${csv_basename}"

    cat setup_files/populate_fhv_trips.sql | run_psql
    echo "$(date): loaded trips for ${csv_basename}"

    docker exec ${CONTAINER_NAME} rm -f /data/${csv_basename}
    echo "$(date): deleted ${csv_basename}"
  fi
done

echo ""
echo "=============================================="
echo "Finished importing ${YEAR_FILTER} data!"
echo "=============================================="
