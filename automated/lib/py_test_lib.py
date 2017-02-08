import sys
import platform


def detect_abi():
    abi = platform.machine()

    armeabi = ['armv7', 'armv7l', 'armv7el', 'armv7lh']
    arm64 = ['arm64', 'armv8', 'arm64-v8a', 'aarch64']

    if abi in armeabi:
        abi = 'armeabi'
    elif abi in arm64:
        abi = 'arm64'
    else:
        print('ERROR: Unsupported Arch: %s' % abi)
        sys.exit(1)

    return abi


def add_result(result_file, result):
    print(result)
    with open(result_file, 'a') as f:
        f.write('%s\n' % result)
