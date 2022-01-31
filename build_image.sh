#!/usr/bin/env bash

set -e

cd docker_image
docker build -t tflite_runtime_rpi0:latest --target dockerpi-vm .
