#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

TENSORFLOW_DIR="tensorflow_src"
git clone https://github.com/tensorflow/tensorflow.git ${TENSORFLOW_DIR}
patch -p0 < ${SCRIPT_DIR}/cmakelists.patch

TENSORFLOW_DIR="${SCRIPT_DIR}/${TENSORFLOW_DIR}"
TENSORFLOW_LITE_DIR="${TENSORFLOW_DIR}/tensorflow/lite"
TENSORFLOW_VERSION=$(grep "_VERSION = " "${TENSORFLOW_DIR}/tensorflow/tools/pip_package/setup.py" | cut -d= -f2 | sed "s/[ '-]//g")
export PACKAGE_VERSION="${TENSORFLOW_VERSION}"
export TF_ENABLE_XLA=0

PYTHON_INCLUDE=$(python -c "from sysconfig import get_paths as gp; print(gp()['include'])")
PYBIND11_INCLUDE=$(python -c "import pybind11; print (pybind11.get_include())")
NUMPY_INCLUDE=$(python -c "import numpy; print (numpy.get_include())")
export CROSSTOOL_PYTHON_INCLUDE_PATH=${PYTHON_INCLUDE}

# Build source tree.
rm -rf "${BUILD_DIR}" && mkdir -p "${BUILD_DIR}/tflite_runtime"
cp -r "${TENSORFLOW_LITE_DIR}/tools/pip_package/debian" \
  "${TENSORFLOW_LITE_DIR}/tools/pip_package/MANIFEST.in" \
  "${TENSORFLOW_LITE_DIR}/python/interpreter_wrapper" \
  "${BUILD_DIR}"
cp "${TENSORFLOW_LITE_DIR}/tools/pip_package/setup_with_binary.py" "${BUILD_DIR}/setup.py"
cp "${TENSORFLOW_LITE_DIR}/python/interpreter.py" \
  "${TENSORFLOW_LITE_DIR}/python/metrics/metrics_interface.py" \
  "${TENSORFLOW_LITE_DIR}/python/metrics/metrics_portable.py" \
  "${BUILD_DIR}/tflite_runtime"
echo "__version__ = '${TENSORFLOW_VERSION}'" >> "${BUILD_DIR}/tflite_runtime/__init__.py"
echo "__git_version__ = '$(git -C "${TENSORFLOW_DIR}" describe)'" >> "${BUILD_DIR}/tflite_runtime/__init__.py"

# Build python interpreter_wrapper.
mkdir -p "${BUILD_DIR}/cmake_build"
cd "${BUILD_DIR}/cmake_build"

ARMCC_PREFIX=/usr/bin/arm-linux-gnueabihf-
ARMCC_FLAGS="-marm -mfpu=vfp -funsafe-math-optimizations -isystem ${CROSSTOOL_PYTHON_INCLUDE_PATH} -I${PYBIND11_INCLUDE} -I${NUMPY_INCLUDE}"
cmake \
  -DCMAKE_C_COMPILER=${ARMCC_PREFIX}gcc \
  -DCMAKE_CXX_COMPILER=${ARMCC_PREFIX}g++ \
  -DCMAKE_C_FLAGS="${ARMCC_FLAGS}" \
  -DCMAKE_CXX_FLAGS="${ARMCC_FLAGS}" \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=armv6 \
  -DTFLITE_ENABLE_XNNPACK=OFF \
  "${TENSORFLOW_LITE_DIR}"

cmake --build . --verbose -j$(nproc) -t _pywrap_tensorflow_interpreter_wrapper

cd "${BUILD_DIR}"
cp "${BUILD_DIR}/cmake_build/_pywrap_tensorflow_interpreter_wrapper.so" "${BUILD_DIR}/tflite_runtime/"
chmod u+w "${BUILD_DIR}/tflite_runtime/_pywrap_tensorflow_interpreter_wrapper.so"

cd "${BUILD_DIR}"
WHEEL_PLATFORM_NAME="linux-armv6l"
python setup.py bdist --plat-name=${WHEEL_PLATFORM_NAME} bdist_wheel --plat-name=${WHEEL_PLATFORM_NAME}

echo "Output can be found here:"
find "${BUILD_DIR}/dist"
