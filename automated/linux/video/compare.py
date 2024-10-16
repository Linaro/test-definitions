# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Qualcomm Inc.

import cv2
import numpy as np
import requests
import sys
from argparse import ArgumentParser
from skimage.metrics import structural_similarity

parser = ArgumentParser()
parser.add_argument("--reference", required=True, help="Reference image path")
auth_group = parser.add_mutually_exclusive_group()
auth_group.add_argument(
    "--reference-auth-user", help="Username required to download reference image"
)
parser.add_argument(
    "--reference-auth-password", help="Password required to download reference image"
)
auth_group.add_argument(
    "--reference-auth-token", help="Token required to download reference image"
)
parser.add_argument(
    "--threshold",
    required=True,
    type=float,
    help="Minimal threshold to pass the test. Value must be between 0 and 1",
)
parser.add_argument(
    "--lava",
    default=True,
    action="store_true",
    help="Print results in LAVA friendly format",
)
parser.add_argument("--no-lava", dest="lava", action="store_false")
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--device", help="Video device to capture image from")
group.add_argument("--image", help="Compared image path")

args = parser.parse_args()

if args.threshold < 0 or args.threshold > 1:
    print(f"Invalid threshold: {args.threshold}")
    sys.exit(1)

first = None

if args.reference.startswith("http"):
    # download reference image
    s = requests.Session()
    if args.reference_auth_user and args.reference_auth_password:
        s.auth = (args.reference_auth_user, args.reference_auth_password)
    if args.reference_auth_token:
        s.headers.update({"Authorization": f"Token {args.reference_auth_token}"})
    s.stream = True
    print(f"Retrieving reference from: {args.reference}")
    first_resp = s.get(args.reference)
    data = first_resp.raw.read()
    first = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)

else:
    first = cv2.imread(args.reference)

second = None

if args.device is not None:
    cam = cv2.VideoCapture(args.device)

    if not (cam.isOpened()):
        print(f"Could not open video device {args.device}")
        sys.exit(1)

    cam.set(cv2.CAP_PROP_FRAME_WIDTH, first.shape[1])
    cam.set(cv2.CAP_PROP_FRAME_HEIGHT, first.shape[0])
    ret, second = cam.read()
    cam.release()
    cv2.destroyAllWindows()

if args.image:
    second = cv2.imread(args.image)

first_gray = cv2.cvtColor(first, cv2.COLOR_BGR2GRAY)
second_gray = cv2.cvtColor(second, cv2.COLOR_BGR2GRAY)

score, diff = structural_similarity(first_gray, second_gray, full=True)
print("Similarity Score: {:.3f}%".format(score * 100))
print("Required threshold: {:.3f}%".format(args.threshold * 100))
if score < args.threshold:
    print("Test fail")
    if args.lava:
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=video_output RESULT=fail>")
else:
    print("Test pass")
    if args.lava:
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=video_output RESULT=pass>")
