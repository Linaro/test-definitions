#!/bin/sh

lcov -c -o coverage.info && echo "LAVA gcov-read: pass" || echo "LAVA gcov-read: fail"

genhtml coverage.info -o gcov_test_coverage && echo "LAVA gcov-html: pass" || echo "LAVA gcov-html: fail"
tar czf gcov-results.tar.gz gcov_test_coverage
if [ -f gcov-results.tar.gz ]; then
    lava-test-run-attach gcov-results.tar.gz application/x-gzip
fi
