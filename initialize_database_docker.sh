#!/bin/bash

# Initialize NYC Taxi Database in Docker Container
# This script should be run from the project root directory

set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-nyc-taxi-postgres}"
DB_NAME="${POSTGRES_DB:-nyc-taxi-data}"
DB_USER="${POSTGRES_USER:-postgres}"

echo "=============================================="
echo "Initializing NYC Taxi Database in Container"
echo "Container: ${CONTAINER_NAME}"
echo "Database: ${DB_NAME}"
echo "=============================================="

# Function to run psql commands in container
run_psql() {
    docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} "$@"
}

# Function to run command in container
run_in_container() {
    docker exec -i ${CONTAINER_NAME} "$@"
}

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; do
    echo "PostgreSQL is not ready yet. Waiting..."
    sleep 2
done
echo "PostgreSQL is ready!"

# Create schema (handle if PostGIS already exists)
echo ""
echo "--- Creating database schema ---"
# First create PostGIS extension if not exists
run_psql -c "CREATE EXTENSION IF NOT EXISTS postgis;"
# Then run the rest of schema (skip CREATE EXTENSION line)
grep -v "CREATE EXTENSION postgis" setup_files/create_nyc_taxi_schema.sql | run_psql
echo "Schema created successfully!"

# Import taxi zones shapefile
echo ""
echo "--- Importing taxi zones shapefile ---"
docker exec ${CONTAINER_NAME} bash -c "shp2pgsql -s 2263:4326 -I /shapefiles/taxi_zones/taxi_zones.shp | psql -U ${DB_USER} -d ${DB_NAME}"
run_psql -c "CREATE INDEX ON taxi_zones (locationid);"
run_psql -c "VACUUM ANALYZE taxi_zones;"
echo "Taxi zones imported successfully!"

# Import NYC Census Tracts shapefile
echo ""
echo "--- Importing NYC Census Tracts shapefile ---"
docker exec ${CONTAINER_NAME} bash -c "shp2pgsql -s 2263:4326 -I /shapefiles/nyct2010_15b/nyct2010.shp | psql -U ${DB_USER} -d ${DB_NAME}"
cat setup_files/add_newark_airport.sql | run_psql
run_psql -c "CREATE INDEX ON nyct2010 (ntacode);"
run_psql -c "VACUUM ANALYZE nyct2010;"
echo "NYC Census Tracts imported successfully!"

# Add tract to zone mapping
echo ""
echo "--- Adding tract to zone mapping ---"
cat setup_files/add_tract_to_zone_mapping.sql | run_psql
echo "Tract to zone mapping added successfully!"

# Import FHV bases data
echo ""
echo "--- Importing FHV bases data ---"
cat data/fhv_bases.csv | run_psql -c "COPY fhv_bases FROM stdin WITH CSV HEADER;"
echo "FHV bases imported successfully!"

# Import weather data
echo ""
echo "--- Importing weather data ---"
weather_schema="station_id, station_name, date, average_wind_speed, precipitation, snowfall, snow_depth, max_temperature, min_temperature"
cat data/central_park_weather.csv | run_psql -c "COPY central_park_weather_observations (${weather_schema}) FROM stdin WITH CSV HEADER;"
run_psql -c "UPDATE central_park_weather_observations SET average_wind_speed = NULL WHERE average_wind_speed = -9999;"
echo "Weather data imported successfully!"

echo ""
echo "=============================================="
echo "Database initialization completed!"
echo "=============================================="
