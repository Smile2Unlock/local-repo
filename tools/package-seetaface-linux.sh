#!/usr/bin/env bash
# Package the installed Linux SDK built with tools/build-sdk in Ubuntu 24.04.
set -euo pipefail
[[ $# == 2 ]] || { echo "usage: $0 PACKAGE_DIR OUTPUT_DIR" >&2; exit 1; }
package_dir="$(realpath "$1")"
mkdir -p "$2"
output_dir="$(realpath "$2")"
revision="a32e2faa0694c0f841ace4df9ead0407b78363c6"
grep -q 'plat = "linux"' "${package_dir}/manifest.txt"
grep -q 'arch = "x86_64"' "${package_dir}/manifest.txt"
grep -q 'debug = false' "${package_dir}/manifest.txt"
[[ "$(git -C "${package_dir}/src" rev-parse HEAD)" == "$revision" ]]
for library in SeetaFaceAntiSpoofingX600 SeetaFaceDetector600 SeetaFaceLandmarker600 SeetaFaceRecognizer610 SeetaAuthorize tennis; do
    [[ -f "${package_dir}/lib64/lib${library}.so" ]]
done
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
for directory in include lib lib64 bin cmake; do
    [[ ! -d "${package_dir}/${directory}" ]] || cp -a "${package_dir}/${directory}" "$temporary/"
done
mkdir -p "${temporary}/src/TenniS" "${temporary}/src/FaceRecognizer6/example" "${temporary}/src/FaceAntiSpoofingX6/example"
cp -a "${package_dir}/src/TenniS/include" "${package_dir}/src/TenniS/src" "${temporary}/src/TenniS/"
cp "${package_dir}/src/FaceRecognizer6/example/1.png" "${temporary}/src/FaceRecognizer6/example/"
cp "${package_dir}/src/FaceAntiSpoofingX6/example/hu.ge.jpg" "${temporary}/src/FaceAntiSpoofingX6/example/"
cp "${package_dir}/src/LICENSE" "${temporary}/LICENSE"
python3 - "$temporary" "$revision" <<'PY'
import json, re, subprocess, sys
from pathlib import Path
root, revision = Path(sys.argv[1]), sys.argv[2]
requirements = {}
for library in (root / 'lib64').glob('*.so*'):
    if library.is_symlink():
        continue
    symbols = subprocess.check_output(['objdump', '-T', str(library)], text=True)
    for name, version in re.findall(r'\((GLIBCXX|GLIBC|CXXABI|GOMP|OMP)_([\d.]+)\)', symbols):
        key = tuple(map(int, version.split('.')))
        previous = requirements.get(name, '0')
        if key > tuple(map(int, previous.split('.'))):
            requirements[name] = version
comment = subprocess.check_output(['readelf', '-p', '.comment',
    str(root / 'lib64/libSeetaFaceDetector600.so')], text=True)
info = {
    'source_commit': revision, 'plat': 'linux', 'arch': 'x86_64',
    'compiler': re.search(r'GCC: ([^\n]+)', comment).group(1).strip(),
    'runtime_requirements': requirements,
}
# Reject accidental builds against the host's much newer runtime.
assert tuple(map(int, requirements['GLIBC'].split('.'))) <= (2, 39), requirements
assert tuple(map(int, requirements['GLIBCXX'].split('.'))) <= (3, 4, 32), requirements
(root / 'PREBUILT.json').write_text(json.dumps(info, indent=2) + '\n')
PY
archive="seetaface6open-linux-x86_64-a32e2fa.tar.gz"
tar -czf "${output_dir}/${archive}" -C "$temporary" .
(cd "$output_dir" && sha256sum "$archive" > "${archive}.sha256")
echo "created ${output_dir}/${archive}"
