#!/bin/bash

# Build the Docker image with GUI enabled and assign proper tag
docker build --no-cache --build-arg GUI=ON -t seiscomp:6.7.6 .

