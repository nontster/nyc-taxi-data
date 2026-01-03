#!/bin/bash

# Download only 2025 data
wget -i setup_files/raw_data_urls_2025.txt -P data/ -w 2
