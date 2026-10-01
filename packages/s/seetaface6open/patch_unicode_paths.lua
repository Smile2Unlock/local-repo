-- Patch only the pinned SDK's runtime model/file readers. Fail closed if
-- upstream changes a call site, so a successful build cannot silently keep
-- an ANSI reader. Each edited directory gets the same C++11 helper header.
function main(srcdir, helper)
    local edits = {
        {"OpenRoleZoo/src/orz/io/stream/filestream.cpp", {
            {"m_in(file.c_str(),", "m_in(su_seetaface::native_path(file).c_str(),", 1},
            {"m_out(file.c_str(),", "m_out(su_seetaface::native_path(file).c_str(),", 1}
        }},
        {"OpenRoleZoo/src/orz/io/stream/modelfilestream.cpp", {
            {"reader(file.c_str(),", "reader(su_seetaface::native_path(file).c_str(),", 1}
        }},
        {"SeetaAuthorize/src/cstamodelfilestream.cpp", {
            {"reader( file.c_str(),", "reader( su_seetaface::native_path(file).c_str(),", 1}
        }},
        {"TenniS/src/runtime/importor.cpp", {
            {"m_handle = LOAD_LIBRARY(dll_name.c_str());", [[#if TS_PLATFORM_OS_WINDOWS
        m_handle = LoadLibraryW(su_seetaface::native_path(dll_name).c_str());
#else
        m_handle = LOAD_LIBRARY(dll_name.c_str());
#endif]], 1}
        }},
        {"TenniS/src/runtime/switcher.cpp", {
            {'const std::string tennis_dll_name = "tennis";', [[#if defined(__MINGW32__)
const std::string tennis_dll_name = "libtennis";
#else
const std::string tennis_dll_name = "tennis";
#endif]], 1},
            {'#if TS_PLATFORM_OS_WINDOWS\nconst std::string tennis_avx_fma_dll', [[#if TS_PLATFORM_OS_WINDOWS && defined(__MINGW32__)
const std::string tennis_avx_fma_dll = "libtennis_haswell.dll";
const std::string tennis_avx_dll = "libtennis_sandy_bridge.dll";
const std::string tennis_sse_dll = "libtennis_pentium.dll";
#elif TS_PLATFORM_OS_WINDOWS
const std::string tennis_avx_fma_dll]], 1},
            {"GetModuleHandleA(model_name.c_str())", "GetModuleHandleW(su_seetaface::native_path(model_name).c_str())", 1},
            {"GetModuleHandleA(model_named.c_str())", "GetModuleHandleW(su_seetaface::native_path(model_named).c_str())", 1},
            {"int num = GetModuleFileNameA(hmodule, sLine, sizeof(sLine));\n         std::string tmp(sLine, num);", [[std::wstring wide_path(256, L'\0');
         while (true) {
             const auto length = GetModuleFileNameW(hmodule, &wide_path[0], static_cast<DWORD>(wide_path.size()));
             if (length == 0) return "";
             if (length < wide_path.size()) {
                 wide_path.resize(length);
                 break;
             }
             if (wide_path.size() >= 32768) return "";
             wide_path.resize(wide_path.size() * 2);
         }
         std::string tmp = su_seetaface::utf8_from_native(wide_path);]], 1}
        }},
        {"TenniS/src/module/io/fstream.cpp", {
            {"m_stream(path,", "m_stream(su_seetaface::native_path(path).c_str(),", 3},
            {"m_stream.open(path,", "m_stream.open(su_seetaface::native_path(path).c_str(),", 3}
        }},
        {"TenniS/src/encryption/aes_fstream.cpp", {
            {"m_stream(path,", "m_stream(su_seetaface::native_path(path).c_str(),", 2}
        }},
        {"TenniS/include/api/cpp/stream.h", {
            {"m_stream(path,", "m_stream(su_seetaface::native_path(path).c_str(),", 2},
            {"m_stream.open(path,", "m_stream.open(su_seetaface::native_path(path).c_str(),", 2}
        }},
        {"FaceBoxes/FaceDetector/src/seeta/FaceDetector.cpp", {
            {"ifs(filename,", "ifs(su_seetaface::native_path(filename).c_str(),", 1}
        }},
        {"Landmarker/Landmarker/src/seeta/FaceLandmarker.cpp", {
            {"ifs(filename,", "ifs(su_seetaface::native_path(filename).c_str(),", 1}
        }},
        {"FaceRecognizer6/FaceRecognizer/src/seeta/FaceRecognizer.cpp", {
            {"ifs(filename,", "ifs(su_seetaface::native_path(filename).c_str(),", 1}
        }},
        {"FaceRecognizer6/FaceRecognizer/include/seeta/Stream.h", {
            {"fopen_s(&iofile, path.c_str(), mode_str.c_str());",
             "iofile = su_seetaface::fopen_utf8(path, mode_str);", 1},
            {"iofile = std::fopen(path.c_str(), mode_str.c_str());",
             "iofile = su_seetaface::fopen_utf8(path, mode_str);", 1}
        }}
    }
    for _, edit in ipairs(edits) do
        local file = path.join(srcdir, edit[1])
        local content = assert(io.readfile(file), "missing pinned SeetaFace source: " .. file)
        if not content:find('#include "su_utf8_path.h"', 1, true) then
            for _, replacement in ipairs(edit[2]) do
                local pattern = replacement[1]:gsub("(%W)", "%%%1")
                local count
                content, count = content:gsub(pattern, function () return replacement[2] end)
                assert(count == replacement[3], "SeetaFace Unicode patch mismatch: " .. file)
            end
            io.writefile(file, '#include "su_utf8_path.h"\n' .. content)
        end
        os.cp(helper, path.join(path.directory(file), "su_utf8_path.h"))
    end
end
