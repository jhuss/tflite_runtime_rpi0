#!/usr/bin/env bash

set -e

apt-get update
apt-get install -y --no-install-recommends \
  software-properties-common \
  pkg-config \
  wget \
  curl \
  unzip \
  zip \
  git \
  build-essential \
  cmake \
  libpython3-dev \
  python3-dev \
  python3-distutils \
  python3-pip \
  python3-venv \
  python3-numpy \
  python3-pybind11
