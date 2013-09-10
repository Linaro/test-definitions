#!/bin/sh

set -x

netserver && echo 'test_case_id:netserver units:none measurement:0 result:pass' || echo 'test_case_id:netserver units:none measurement:0 result:fail'
