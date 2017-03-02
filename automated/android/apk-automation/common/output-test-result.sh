#!/bin/bash

local_common_file_path="$0"
# shellcheck disable=SC2164
local_common_parent_dir=$(cd "$(dirname "${local_common_file_path}")"; pwd)
# shellcheck disable=SC1090
source "${local_common_parent_dir}/common2.sh"

output_test_result "$@"
