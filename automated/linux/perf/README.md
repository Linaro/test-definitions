# Perf tests

Set `TESTPROG_URL` to test a prebuilt perf archive, such as TuxMake's
`perf.tar.xz`. It must contain `usr/bin/perf` and `usr/libexec/perf-core`.
The runner uses these installed files from a private directory.

Bundled library directories under `usr/lib` are added to the library search
path. Other runtime packages are installed on Debian or Ubuntu unless
`SKIP_INSTALL=true`; in that case, provide them in the rootfs.

Without `TESTPROG_URL`, the existing distro perf path is used. A startup check
reports missing libraries before any functional tests run.
