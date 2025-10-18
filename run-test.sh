#!/bin/bash

# Ensure we are in the app directory
cd /app || exit 1

# Install any missing requirements (optional if already in Dockerfile)
pip install --no-cache-dir -r requirements.txt

# Run pytest
pytest || exit $?   # Exit with pytest's code

