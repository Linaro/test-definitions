# inference

Image classification (MobileNetV2, seven images) on every processing unit a
board has, with one model and one set of inputs, checked and timed the same
way on each: every image's top-1, latency per inference (mean, p50, p90 after
warm-up), each accelerator against the CPU running the same runtime, the HTP
against the x86 HTP simulation of its Hexagon architecture, TensorFlow Lite on
the CPU against the x86 LiteRT run, and a comparison table at the end of the
log.

## Processing units

`PUS` lists what the board has, one entry per unit and runtime:

| Entry | Runtime |
|---|---|
| `cpu:qnn` | QAIRT QNN CPU backend, fp32 DLC |
| `npu<N>:qnn-htp:<arch>:<device id>:<remoteproc>` | QNN HTP backend on Hexagon NSP `<N>` (QNN device id), over FastRPC, 8-bit DLC |
| `npu<N>:qnn-dsp:<arch>:<device id>:<remoteproc>` | QNN DSP backend on a Hexagon DSP with HVX and no HTP (v66), 8-bit DLC |
| `cpu:tflite[:<threads>]` | TensorFlow Lite with XNNPACK (default 4 threads) |
| `gpu:tflite-gpu[:fp16\|fp32]` | TensorFlow Lite GPU delegate (OpenCL); after `cpu:tflite` |

`ABSENT` names units the board lacks, as `<pu>=<reason>;...`: each is
reported as skip with its reason.

## Inputs

- `QAIRT_ZIP`: the Qualcomm AI Runtime SDK zip as Qualcomm publishes it,
  checked against `QAIRT_SHA256`. Its license does not allow redistributing
  it on its own, so the job provides it (for LAVA, e.g. a file overlay
  downloaded from Qualcomm's URL). The test extracts only the files it runs:
  `qnn-net-run`, `qnn-profile-viewer`, the backends and, for the HTP and DSP
  entries, the Hexagon stubs and skels of `<arch>` (`QNN_TARGET` and
  `QAIRT_ROOT` locate them in the zip).
- `MODEL_DIR`: the model bundle.
- `tflite-run` (`tflite-run.cc`): runs a TensorFlow Lite model on the raw
  inputs and writes each output and the time of each `Invoke()`, in the
  layout `qnn-net-run` uses. When it is not installed, `make tflite-run`
  builds it against an installed TensorFlow Lite. TensorFlow Lite's
  `label_image` and `benchmark_model` do not write the raw output tensors
  that the comparisons need.

Without the zip, the bundle or `tflite-run`, the entries that need them are
reported as skip with the reason.

## Model bundle

```
model.env            MODEL_NAME, CPU_DLC, HTP_DLC, TFLITE, TFLITE_INPUTS
<CPU_DLC>            fp32 DLC (QNN CPU)
<HTP_DLC>            8-bit DLC (QNN HTP and DSP)
<TFLITE>             TensorFlow Lite model
inputs/<name>.raw    float32 input of each image for the DLCs
<TFLITE_INPUTS>/<name>.raw
                     the same inputs in the TensorFlow Lite model's layout
expected.txt         "<name> <class>" per image, in order
labels.txt           one class name per line
host-htp-<arch>/<name>.raw
                     x86 QNN HTP simulation output of each Hexagon arch
                     (host-htp/ when there is only one)
host-tflite/<name>.raw
                     x86 LiteRT output of the TensorFlow Lite model
MANIFEST.sha256      sha256sum of every file above
```

`model.env` is read as `KEY=value` lines, never executed. The bundle is
built on an x86_64 host with the QAIRT converters and LiteRT, from the ONNX
model zoo MobileNetV2 and public domain images.

## Negative controls

`NEGATIVE=htp-down` stops the remoteproc of each HTP or DSP entry before its
run, so its cases must fail; `gpu-down` hides the OpenCL platforms from the
GPU entries; `wrong-class` rotates the expected classes, so every top-1 case
must fail.
