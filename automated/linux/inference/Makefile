# SPDX-License-Identifier: BSD-2-Clause
# tflite-run against an installed TensorFlow Lite (headers and
# libtensorflow-lite). NO_GPU=1 or NO_XNNPACK=1 for a TensorFlow Lite built
# without the GPU delegate or XNNPACK.
CXX ?= g++
CXXFLAGS ?= -O2
CXXFLAGS += -std=c++17 -Wall
LDLIBS += -ltensorflow-lite
ifneq ($(NO_GPU),)
CXXFLAGS += -DTFLITE_RUN_NO_GPU
endif
ifneq ($(NO_XNNPACK),)
CXXFLAGS += -DTFLITE_RUN_NO_XNNPACK
endif

tflite-run: tflite-run.cc
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f tflite-run
