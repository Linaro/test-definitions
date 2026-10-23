// SPDX-License-Identifier: BSD-2-Clause
// Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
/*
 * tflite-run: run a TensorFlow Lite model on a list of raw input files, as
 * qnn-net-run does for QNN models, so that the same test checks both.
 *
 *   tflite-run --model <m.tflite> --input_list <list> --output_dir <dir>
 *              [--delegate xnnpack|gpu] [--threads <n>] [--gpu_fp16]
 *
 * Each line of the list names a raw file holding the model's first input
 * tensor (its bytes, in the tensor's type and layout). For line <i> the first
 * output tensor is written to <dir>/Result_<i>/output.raw and the time of
 * the Invoke() call, in microseconds, is appended to <dir>/times.txt. With
 * --delegate gpu the whole graph must run on the GPU delegate (OpenCL
 * backend); a model the delegate cannot take fully is an error. Prints the
 * delegate and the number of nodes before and after delegation.
 */
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <sys/stat.h>
#include <vector>

#ifndef TFLITE_RUN_NO_GPU
#include "tensorflow/lite/delegates/gpu/delegate.h"
#endif
#ifndef TFLITE_RUN_NO_XNNPACK
#include "tensorflow/lite/delegates/xnnpack/xnnpack_delegate.h"
#endif
#include "tensorflow/lite/interpreter.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"

namespace {

int usage()
{
	std::cerr << "usage: tflite-run --model <m.tflite> --input_list <list> "
		     "--output_dir <dir> [--delegate xnnpack|gpu] [--threads <n>] "
		     "[--gpu_fp16]\n";
	return 1;
}

bool read_file(const std::string &path, std::vector<char> &buf)
{
	std::ifstream f(path, std::ios::binary | std::ios::ate);
	if (!f)
		return false;
	buf.resize(f.tellg());
	f.seekg(0);
	return static_cast<bool>(f.read(buf.data(), buf.size()));
}

}  // namespace

int main(int argc, char **argv)
{
	std::string model_path, list_path, out_dir, delegate = "xnnpack";
	int threads = 1;
	bool gpu_fp16 = false;

	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		if (a == "--gpu_fp16") {
			gpu_fp16 = true;
			continue;
		}
		if (i + 1 >= argc)
			return usage();
		if (a == "--model")
			model_path = argv[++i];
		else if (a == "--input_list")
			list_path = argv[++i];
		else if (a == "--output_dir")
			out_dir = argv[++i];
		else if (a == "--delegate")
			delegate = argv[++i];
		else if (a == "--threads")
			threads = std::atoi(argv[++i]);
		else
			return usage();
	}
	if (model_path.empty() || list_path.empty() || out_dir.empty() ||
	    (delegate != "xnnpack" && delegate != "gpu") || threads < 1)
		return usage();

	auto model = tflite::FlatBufferModel::BuildFromFile(model_path.c_str());
	if (!model) {
		std::cerr << "cannot load " << model_path << "\n";
		return 2;
	}
	tflite::ops::builtin::BuiltinOpResolverWithoutDefaultDelegates resolver;
	std::unique_ptr<tflite::Interpreter> interp;
	if (tflite::InterpreterBuilder(*model, resolver)(&interp) != kTfLiteOk ||
	    !interp) {
		std::cerr << "cannot build the interpreter\n";
		return 2;
	}
	interp->SetNumThreads(threads);
	const size_t nodes = interp->execution_plan().size();

	TfLiteDelegate *d = nullptr;
	if (delegate == "gpu") {
#ifdef TFLITE_RUN_NO_GPU
		std::cerr << "built without the GPU delegate\n";
		return 3;
#else
		TfLiteGpuDelegateOptionsV2 o = TfLiteGpuDelegateOptionsV2Default();
		o.experimental_flags |= TFLITE_GPU_EXPERIMENTAL_FLAGS_CL_ONLY;
		o.inference_preference =
			TFLITE_GPU_INFERENCE_PREFERENCE_SUSTAINED_SPEED;
		if (gpu_fp16) {
			o.is_precision_loss_allowed = 1;
			o.inference_priority1 =
				TFLITE_GPU_INFERENCE_PRIORITY_MIN_LATENCY;
		}
		d = TfLiteGpuDelegateV2Create(&o);
#endif
	} else {
#ifdef TFLITE_RUN_NO_XNNPACK
		std::cerr << "built without XNNPACK\n";
		return 3;
#else
		TfLiteXNNPackDelegateOptions o = TfLiteXNNPackDelegateOptionsDefault();
		o.num_threads = threads;
		d = TfLiteXNNPackDelegateCreate(&o);
#endif
	}
	if (!d || interp->ModifyGraphWithDelegate(d) != kTfLiteOk) {
		std::cerr << "cannot apply the " << delegate << " delegate\n";
		return 3;
	}
	const size_t left = interp->execution_plan().size();
	std::cout << "delegate " << delegate << " threads " << threads
		  << (delegate == "gpu" ? (gpu_fp16 ? " fp16" : " fp32") : "")
		  << ": " << nodes << " nodes, " << left
		  << " after delegation\n";
	if (delegate == "gpu" && left != 1) {
		std::cerr << "the GPU delegate did not take the whole graph\n";
		return 3;
	}
	if (interp->AllocateTensors() != kTfLiteOk) {
		std::cerr << "cannot allocate tensors\n";
		return 2;
	}

	TfLiteTensor *in = interp->input_tensor(0);
	const TfLiteTensor *out = interp->output_tensor(0);
	std::ifstream list(list_path);
	std::ofstream times(out_dir + "/times.txt");
	if (!list || !times) {
		std::cerr << "cannot open " << list_path << " or " << out_dir
			  << "/times.txt\n";
		return 2;
	}
	std::string line;
	std::vector<char> buf;
	int n = 0;
	while (std::getline(list, line)) {
		if (line.empty())
			continue;
		if (!read_file(line, buf) || buf.size() != in->bytes) {
			std::cerr << line << ": not " << in->bytes << " bytes\n";
			return 4;
		}
		std::memcpy(in->data.raw, buf.data(), buf.size());
		auto t0 = std::chrono::steady_clock::now();
		if (interp->Invoke() != kTfLiteOk) {
			std::cerr << "Invoke failed on " << line << "\n";
			return 5;
		}
		auto t1 = std::chrono::steady_clock::now();
		times << std::chrono::duration_cast<std::chrono::microseconds>(
				 t1 - t0).count() << "\n";
		std::string dir = out_dir + "/Result_" + std::to_string(n);
		mkdir(dir.c_str(), 0755);
		std::ofstream o(dir + "/output.raw", std::ios::binary);
		o.write(out->data.raw, out->bytes);
		if (!o) {
			std::cerr << "cannot write " << dir << "/output.raw\n";
			return 2;
		}
		n++;
	}
	std::cout << n << " inferences\n";
	// The delegate must outlive the interpreter that uses it.
	interp.reset();
#ifndef TFLITE_RUN_NO_GPU
	if (delegate == "gpu")
		TfLiteGpuDelegateV2Delete(d);
#endif
#ifndef TFLITE_RUN_NO_XNNPACK
	if (delegate == "xnnpack")
		TfLiteXNNPackDelegateDelete(d);
#endif
	return n > 0 ? 0 : 4;
}
