#ifndef SU_SEETAFACE_UTF8_PATH_H_
#define SU_SEETAFACE_UTF8_PATH_H_

// SeetaFace's public model paths are UTF-8. Preserve that contract at the
// Windows file boundary instead of passing the bytes to the ANSI CRT.
// Keep C++11 compatibility with the pinned upstream sources.
#include <cstdio>
#include <limits>
#include <stdexcept>
#include <string>

#if defined(_WIN32)
// Do not include windows.h here: its VOID macro and INT32 typedef collide
// with TenniS's dtype names in public SDK headers. This is the Win32 ABI.
extern "C" __declspec(dllimport) int __stdcall MultiByteToWideChar(
    unsigned int, unsigned long, const char*, int, wchar_t*, int);
extern "C" __declspec(dllimport) int __stdcall WideCharToMultiByte(
    unsigned int, unsigned long, const wchar_t*, int, char*, int, const char*, int*);
#endif

namespace su_seetaface {

#if defined(_WIN32)
inline std::wstring native_path(const std::string& utf8) {
    if (utf8.empty()) return {};
    if (utf8.size() > static_cast<std::size_t>((std::numeric_limits<int>::max)())
        || utf8.find('\0') != std::string::npos) {
        throw std::invalid_argument("invalid UTF-8 file path");
    }
    const auto length = ::MultiByteToWideChar(
        65001 /* CP_UTF8 */, 8 /* MB_ERR_INVALID_CHARS */,
        utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
    if (length <= 0) throw std::invalid_argument("invalid UTF-8 file path");
    auto wide = std::wstring(static_cast<std::size_t>(length), L'\0');
    if (::MultiByteToWideChar(65001, 8, utf8.data(),
            static_cast<int>(utf8.size()), &wide[0], length) != length) {
        throw std::invalid_argument("invalid UTF-8 file path");
    }
    return wide;
}

inline std::string utf8_from_native(const std::wstring& wide) {
    if (wide.empty()) return {};
    if (wide.size() > static_cast<std::size_t>((std::numeric_limits<int>::max)())) {
        throw std::invalid_argument("invalid UTF-16 file path");
    }
    const auto length = ::WideCharToMultiByte(65001, 128 /* WC_ERR_INVALID_CHARS */,
        wide.data(), static_cast<int>(wide.size()), nullptr, 0, nullptr, nullptr);
    if (length <= 0) throw std::invalid_argument("invalid UTF-16 file path");
    auto utf8 = std::string(static_cast<std::size_t>(length), '\0');
    if (::WideCharToMultiByte(65001, 128, wide.data(), static_cast<int>(wide.size()),
            &utf8[0], length, nullptr, nullptr) != length) {
        throw std::invalid_argument("invalid UTF-16 file path");
    }
    return utf8;
}
#else
inline const std::string& native_path(const std::string& utf8) { return utf8; }
#endif

inline std::FILE* fopen_utf8(const std::string& path, const std::string& mode) {
#if defined(_WIN32)
    return ::_wfopen(native_path(path).c_str(), native_path(mode).c_str());
#else
    return std::fopen(path.c_str(), mode.c_str());
#endif
}

}  // namespace su_seetaface

#endif
