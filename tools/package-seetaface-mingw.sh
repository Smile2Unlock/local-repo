#!/usr/bin/env bash
# Build first with: xmake f -P tools/build-sdk -y -p mingw -a x86_64 -m release
# Then: xmake build -P tools/build-sdk sdk
# This script packages that installed SDK without its build trees or Git data.
set -euo pipefail
[[ $# == 2 ]] || { echo "usage: $0 PACKAGE_DIR OUTPUT_DIR" >&2; exit 1; }
package_dir="$(realpath "$1")"
mkdir -p "$2"
output_dir="$(realpath "$2")"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
revision="a32e2faa0694c0f841ace4df9ead0407b78363c6"
[[ -f "${package_dir}/manifest.txt" ]] || { echo "missing Xmake manifest" >&2; exit 1; }
grep -q 'plat = "mingw"' "${package_dir}/manifest.txt"
grep -q 'unicode_paths = true' "${package_dir}/manifest.txt"
grep -q 'prebuilt = false' "${package_dir}/manifest.txt"
[[ "$(git -C "${package_dir}/src" rev-parse HEAD)" == "$revision" ]]
for library in SeetaFaceAntiSpoofingX600 SeetaFaceDetector600 SeetaFaceLandmarker600 SeetaFaceRecognizer610 SeetaAuthorize tennis; do
    [[ -f "${package_dir}/lib/x64/lib${library}.dll.a" ]]
    [[ -f "${package_dir}/bin/x64/lib${library}.dll" || -f "${package_dir}/lib/x64/lib${library}.dll" ]]
done
grep -q 'su_utf8_path.h' "${package_dir}/src/TenniS/src/module/io/fstream.cpp"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
for directory in include lib bin cmake; do
    [[ ! -d "${package_dir}/${directory}" ]] || cp -a "${package_dir}/${directory}" "$temporary/"
done
mkdir -p "${temporary}/src/TenniS" "${temporary}/src/FaceRecognizer6/example" "${temporary}/src/FaceAntiSpoofingX6/example"
cp -a "${package_dir}/src/TenniS/include" "${package_dir}/src/TenniS/src" "${temporary}/src/TenniS/"
cp "${package_dir}/src/FaceRecognizer6/example/1.png" "${temporary}/src/FaceRecognizer6/example/"
cp "${package_dir}/src/FaceAntiSpoofingX6/example/hu.ge.jpg" "${temporary}/src/FaceAntiSpoofingX6/example/"
cp "${package_dir}/src/LICENSE" "${temporary}/LICENSE"
python3 - "$temporary" "$revision" "${script_dir}/../packages/s/seetaface6open/utf8_path.h" <<'PY'
import hashlib, json, subprocess, sys
from pathlib import Path
root, revision, patch = sys.argv[1:]
info = {
    'source_commit': revision, 'plat': 'mingw', 'arch': 'x86_64',
    'unicode_paths': True,
    'compiler': subprocess.check_output(['x86_64-w64-mingw32-g++', '-dumpfullversion'], text=True).strip(),
    'unicode_helper_sha256': hashlib.sha256(Path(patch).read_bytes()).hexdigest(),
}
Path(root, 'PREBUILT.json').write_text(json.dumps(info, indent=2)+'\n')
PY
archive="seetaface6open-mingw-x86_64-a32e2fa-unicode.tar.gz"
tar -czf "${output_dir}/${archive}" -C "$temporary" .
(cd "$output_dir" && sha256sum "$archive" > "${archive}.sha256")
echo "created ${output_dir}/${archive}"
