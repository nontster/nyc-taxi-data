#!/usr/bin/env python3
"""
Convert Parquet file to CSV format.
Replacement for convert_parquet_to_csv.R
"""

import sys
import os

try:
    import pyarrow.parquet as pq
    import pyarrow.csv as csv
except ImportError:
    print("Installing required packages...")
    os.system(f"{sys.executable} -m pip install pyarrow --quiet")
    import pyarrow.parquet as pq
    import pyarrow.csv as csv


def convert_parquet_to_csv(parquet_filename):
    """Convert a parquet file to CSV format."""
    if not os.path.exists(parquet_filename):
        print(f"Error: File not found: {parquet_filename}")
        sys.exit(1)
    
    # Generate CSV filename
    csv_filename = parquet_filename.replace('.parquet', '.csv')
    
    # Read parquet file
    table = pq.read_table(parquet_filename)
    print(f"Read {table.num_rows} rows from {parquet_filename}")
    
    # Remove __index_level_0__ column if exists
    if "__index_level_0__" in table.column_names:
        table = table.drop(["__index_level_0__"])
    
    # Write to CSV
    csv.write_csv(table, csv_filename)
    print(f"Wrote {table.num_rows} rows to {csv_filename}")
    
    return csv_filename


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: convert_parquet_to_csv.py <parquet_file>")
        sys.exit(1)
    
    parquet_file = sys.argv[1]
    convert_parquet_to_csv(parquet_file)
