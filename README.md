# Smile2Unlock Xmake packages

Third-party SDKs and face models live in this repository's
[Releases](https://github.com/Smile2Unlock/local-repo/releases).

| Asset | Source and build |
| --- | --- |
| Slint 1.18.1 Linux x86_64 | Unmodified official C++ SDK, mirrored with its upstream SHA-256 |
| Slint 1.18.1 MinGW x86_64 | Host compiler and Windows static runtime, built with Rust 1.99.0; includes the software renderer |
| SeetaFace6 MinGW x86_64 | Source commit `a32e2faa0694c0f841ace4df9ead0407b78363c6`, with Unicode model/DLL path support |
| SeetaFace6 models v1 | Unchanged five-model bundle migrated from Smile2Unlock_v2, including its original checksum and license |

Models: [download](https://github.com/Smile2Unlock/local-repo/releases/download/models-seetaface6-v1/smile2unlock-models-seetaface6-v1.zip),
[checksum](https://github.com/Smile2Unlock/local-repo/releases/download/models-seetaface6-v1/smile2unlock-models-seetaface6-v1.zip.sha256).
The ZIP has a bundle directory above `seeta/`; extract with `--strip-components=1`
when installing into the model directory's parent.

The Slint static runtime and consumer Rust static libraries must use the same
compiler. Smile2Unlock records the exact Rust compiler commit and archive
digest in `packaging/slint/prebuilt-mingw.json` and pins Rust in
`rust-toolchain.toml`.

SeetaFace's package version remains `latest`; its source commit is fixed.
The prebuilt release uses that commit in its name rather than inventing an
upstream version. Linux, debug, non-x86_64, and builds without Unicode paths
continue to use source builds. Set the package's `prebuilt` config to `false`
to build the release MinGW SDK from source too.

To reproduce the SeetaFace SDK:

```sh
xmake f -P tools/build-sdk -y -p mingw -a x86_64 -m release
xmake build -P tools/build-sdk sdk
bash tools/package-seetaface-mingw.sh <printed-package-directory> <output-directory>
```

The SDK contains installed headers, DLLs, import libraries, upstream license,
the TenniS headers and sample images needed by regression tests, and build
provenance in `PREBUILT.json`. Models are downloaded separately.
