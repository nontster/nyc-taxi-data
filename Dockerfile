FROM postgis/postgis:16-3.4

# Install shp2pgsql, Python, and required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgis \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment and install pyarrow
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir pyarrow

# Copy conversion script
COPY setup_files/convert_parquet_to_csv.py /usr/local/bin/convert_parquet_to_csv.py
RUN chmod +x /usr/local/bin/convert_parquet_to_csv.py
