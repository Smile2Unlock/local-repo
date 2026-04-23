package("seetaface6open")
    set_homepage("https://github.com/SeetaFace6Open/index")
    set_description("SeetaFace6Open built from upstream source")
    set_license("BSD-2-Clause")

    if is_plat("linux") then
        add_deps("openmp")
    end

    local core_links = {
        "SeetaFaceAntiSpoofingX600",
        "SeetaFaceDetector600",
        "SeetaFaceLandmarker600",
        "SeetaFaceRecognizer610"
    }

    local function _package_links(package)
        local suffix = package:is_debug() and "d" or ""
        local links = {}
        for _, link in ipairs(core_links) do
            table.insert(links, link .. suffix)
        end
        return links
    end

    local function _package_archdir(package)
        return package:is_arch("x86", "i386") and "x86" or "x64"
    end

    local function _package_libdir(package)
        if package:is_plat("linux") then
            return "lib"
        end
        return path.join("lib", _package_archdir(package))
    end

    local function _package_bindir(package)
        if package:is_plat("linux") then
            return "bin"
        end
        return path.join("bin", _package_archdir(package))
    end

    local function _normalize_binpath(bin)
        if not bin then
            return nil
        end
        if os.isfile(bin) then
            return path.unix(bin)
        end
        if is_host("windows") and os.isfile(bin .. ".exe") then
            return path.unix(bin .. ".exe")
        end
        return path.unix(bin)
    end

    local function _append_flag(current, extra)
        if not extra or extra == "" then
            return current
        end
        if not current or current == "" then
            return extra
        end
        return current .. " " .. extra
    end

    local function _build_configs(package)
        local buildtype = package:is_debug() and "Debug" or "Release"
        local platform = package:is_arch("x86", "i386") and "x86" or "x64"
        local installdir = package:installdir()
        local cmake_installdir = path.unix(installdir)
        local cc = _normalize_binpath(package:build_getenv("cc"))
        local cxx = _normalize_binpath(package:build_getenv("cxx"))
        local configs = {
            CMAKE_BUILD_TYPE = buildtype,
            CONFIGURATION = buildtype,
            PLATFORM = platform,
            TARGET = "SHARED",
            CMAKE_POLICY_VERSION_MINIMUM = "3.10",
            CMAKE_INSTALL_PREFIX = cmake_installdir,
            CMAKE_PREFIX_PATH = cmake_installdir,
            CMAKE_MODULE_PATH = path.unix(path.join(installdir, "cmake")),
            CMAKE_C_COMPILER = cc,
            CMAKE_CXX_COMPILER = cxx
        }
        if package:is_plat("linux") and package:dep("openmp") then
            local openmp = package:dep("openmp"):fetch()
            if openmp then
                configs.CMAKE_C_FLAGS = _append_flag(configs.CMAKE_C_FLAGS, openmp.cflags)
                configs.CMAKE_CXX_FLAGS = _append_flag(configs.CMAKE_CXX_FLAGS, openmp.cxxflags)
                configs.CMAKE_EXE_LINKER_FLAGS = _append_flag(configs.CMAKE_EXE_LINKER_FLAGS, openmp.ldflags)
                configs.CMAKE_SHARED_LINKER_FLAGS = _append_flag(configs.CMAKE_SHARED_LINKER_FLAGS, openmp.shflags)
            end
        end
        if package:is_plat("mingw") then
            configs.CMAKE_CXX_FLAGS = "-Dlocaltime_r(a,b)=localtime_s(b,a)"
        end
        return buildtype, platform, installdir, configs
    end

    local function _msvc_cmake_generators()
        return {
            "Visual Studio 18 2026",
            "Visual Studio 17 2022",
            "Visual Studio 16 2019",
            "Visual Studio 15 2017"
        }
    end

    local function _find_mingw_make(package)
        local mingw = package:build_getenv("mingw") or package:build_getenv("sdk")
        if mingw then
            local make = path.join(mingw, "bin", "mingw32-make.exe")
            if os.isfile(make) then
                return path.unix(make)
            end
        end
    end

    local function _build_jobs()
        local jobs = os.default_njob and os.default_njob() or 8
        if not jobs or jobs < 1 then
            jobs = 8
        end
        return jobs
    end

    on_load(function (package)
        package:add("links", table.unpack(_package_links(package)))
    end)

    on_fetch(function (package)
        local includedir = package:installdir("include")
        local libdir = package:installdir(_package_libdir(package))
        local bindir = package:installdir(_package_bindir(package))
        local marker = path.join(includedir, "seeta", "FaceRecognizer.h")

        local has_any_library = false
        for _, link in ipairs(_package_links(package)) do
            local candidates = {
                path.join(libdir, "lib" .. link .. ".a"),
                path.join(libdir, "lib" .. link .. ".so"),
                path.join(libdir, "lib" .. link .. ".dylib"),
                path.join(libdir, link .. ".lib"),
                path.join(bindir, link .. ".dll")
            }
            if os.isfile(candidates[1])
                or os.isfile(candidates[2])
                or os.isfile(candidates[3])
                or os.isfile(candidates[4])
                or os.isfile(candidates[5]) then
                has_any_library = true
                break
            end
        end

        if not os.isfile(marker) or not has_any_library then
            return nil
        end

        return {
            links = _package_links(package),
            linkdirs = {libdir},
            includedirs = {includedir},
            bindirs = {bindir}
        }
    end)

    on_install(
        "windows|x64",
        "windows|x86",
        "mingw|x86_64",
        "mingw|i386",
        "linux|x86_64",
        "linux|i386",
        function (package)
        local function apply_source_patches(srcdir)
            local pot_h = path.join(srcdir, "OpenRoleZoo", "include", "orz", "mem", "pot.h")
            if os.isfile(pot_h) then
                local content = io.readfile(pot_h)
                if content and not content:find("#include <functional>", 1, true) then
                    content = content:gsub("#include <memory>", "#include <memory>\n#include <functional>", 1)
                    io.writefile(pot_h, content)
                end
            end

            for _, pot_cpp in ipairs(os.files(path.join(srcdir, "TenniS", "**", "pot.cpp"))) do
                local content = io.readfile(pot_cpp)
                if content then
                    if not content:find("#include <cstdlib>", 1, true) then
                        local patched, count = content:gsub('(#include%s+"[^"]-pot%.h")', '%1\n#include <cstdlib>', 1)
                        content = count > 0 and patched or ('#include <cstdlib>\n' .. content)
                    end
                    content = content:gsub(
                        "return%s+std::shared_ptr<void>%(%s*std::malloc%(%s*_size%s*%)%s*,%s*std::free%s*%);",
                        "return std::shared_ptr<void>(std::malloc(_size), [](void *ptr) { std::free(ptr); });",
                        1
                    )
                    content = content:gsub(
                        "return%s+std::shared_ptr<void>%(%s*::malloc%(%s*_size%s*%)%s*,%s*::free%s*%);",
                        "return std::shared_ptr<void>(std::malloc(_size), [](void *ptr) { std::free(ptr); });",
                        1
                    )
                    content = content:gsub(
                        "return%s+std::shared_ptr<void>%(%s*malloc%(%s*_size%s*%)%s*,%s*free%s*%);",
                        "return std::shared_ptr<void>(std::malloc(_size), [](void *ptr) { std::free(ptr); });",
                        1
                    )
                    io.writefile(pot_cpp, content)
                    break
                end
            end

            for _, format_cpp in ipairs(os.files(path.join(srcdir, "OpenRoleZoo", "**", "format.cpp"))) do
                local content = io.readfile(format_cpp)
                if content and content:find("localtime_r%(") and not content:find("localtime_s%(") then
                    content = content:gsub(
                        "localtime_r%s*%(%s*&from%s*,%s*&to%s*%);",
                        "#if defined(_WIN32)\n        localtime_s(&to, &from);\n#else\n        localtime_r(&from, &to);\n#endif",
                        1
                    )
                    io.writefile(format_cpp, content)
                    break
                end
            end

            for _, except_h in ipairs(os.files(path.join(srcdir, "OpenRoleZoo", "**", "except.h"))) do
                local content = io.readfile(except_h)
                if content and content:find("Exception%(const std::string &message%);") then
                    content = content:gsub(
                        "Exception%(const std::string &message%);",
                        "explicit Exception(const std::string &message) : m_message(message) {}",
                        1
                    )
                    content = content:gsub(
                        "virtual const char %*what%(%) const ORZ_NOEXCEPT override;",
                        "virtual const char *what() const ORZ_NOEXCEPT override { return m_message.c_str(); }",
                        1
                    )
                    io.writefile(except_h, content)
                    break
                end
            end

            for _, except_cpp in ipairs(os.files(path.join(srcdir, "OpenRoleZoo", "**", "except.cpp"))) do
                local content = io.readfile(except_cpp)
                if content and content:find("Exception::Exception") then
                    io.writefile(except_cpp, '#include "orz/utils/except.h"\n')
                    break
                end
            end

            for _, importor_cpp in ipairs(os.files(path.join(srcdir, "TenniS", "**", "importor.cpp"))) do
                local content = io.readfile(importor_cpp)
                if content and content:find("return%s+GET_FUC_ADDRESS%(") and not content:find("reinterpret_cast<void %*>%s*%(%s*GET_FUC_ADDRESS%(") then
                    content = content:gsub(
                        "return%s+GET_FUC_ADDRESS%s*%((.-)%)%s*;",
                        "return reinterpret_cast<void *>(GET_FUC_ADDRESS(%1));",
                        1
                    )
                    io.writefile(importor_cpp, content)
                    break
                end
            end

            for _, cpu_info_cpp in ipairs(os.files(path.join(srcdir, "TenniS", "**", "cpu_info.cpp"))) do
                local content = io.readfile(cpu_info_cpp)
                if content and content:find("#if TS_PLATFORM_OS_WINDOWS") and not content:find("#if TS_PLATFORM_OS_WINDOWS && !TS_PLATFORM_CC_MINGW", 1, true) then
                    content = content:gsub(
                        "#if TS_PLATFORM_OS_WINDOWS",
                        "#if TS_PLATFORM_OS_WINDOWS && !TS_PLATFORM_CC_MINGW"
                    )
                    io.writefile(cpu_info_cpp, content)
                    break
                end
            end

            for _, ctxmgr_lite_cpp in ipairs(os.files(path.join(srcdir, "TenniS", "**", "ctxmgr_lite.cpp"))) do
                local content = io.readfile(ctxmgr_lite_cpp)
                if content and content:find("#if TS_PLATFORM_CC_GCC") and not content:find("#if TS_PLATFORM_CC_GCC && !TS_PLATFORM_CC_MINGW", 1, true) then
                    content = content:gsub(
                        "#if TS_PLATFORM_CC_GCC",
                        "#if TS_PLATFORM_CC_GCC && !TS_PLATFORM_CC_MINGW",
                        1
                    )
                    io.writefile(ctxmgr_lite_cpp, content)
                    break
                end
            end
        end

        local git_url = "https://github.com/SeetaFace6Open/index.git"
        local srcdir = path.join(package:installdir(), "src")
        local buildroot = path.join(package:installdir(), "buildtrees")
        local _, platform, installdir, common = _build_configs(package)
        local cmake_installdir = path.unix(installdir)
        local is_msvc = package:is_plat("windows")
        local buildjobs = tostring(_build_jobs())
        local function cmake_define(name, value)
            return "-D" .. name .. "=" .. value
        end
        local function install_module(modulename, configs)
            local sourcedir = path.join(srcdir, modulename)
            local builddir = path.join(buildroot, modulename)
            local function configure(generator)
                if os.isdir(builddir) then
                    os.rm(builddir)
                end
                os.mkdir(builddir)
                local argv = {}
                if generator then
                    table.insert(argv, "-G")
                    table.insert(argv, generator)
                    if is_msvc then
                        table.insert(argv, "-A")
                        table.insert(argv, platform == "x86" and "Win32" or "x64")
                    end
                else
                    if package:is_plat("mingw") then
                        local mingw_make = _find_mingw_make(package)
                        assert(mingw_make, "mingw32-make not found, cannot configure " .. modulename .. " for mingw")
                        table.insert(argv, "-G")
                        table.insert(argv, "MinGW Makefiles")
                        table.insert(argv, cmake_define("CMAKE_MAKE_PROGRAM", mingw_make))
                    end
                end
                for name, value in pairs(configs) do
                    if value then
                        table.insert(argv, cmake_define(name, value))
                    end
                end
                table.insert(argv, path.unix(sourcedir))
                os.vrunv("cmake", argv, {curdir = builddir})
            end

            if is_msvc then
                local configured = false
                for _, generator in ipairs(_msvc_cmake_generators()) do
                    local ok = try {
                        function ()
                            configure(generator)
                            return true
                        end
                    }
                    if ok then
                        configured = true
                        break
                    end
                end
                assert(configured, "failed to configure " .. modulename .. " with any supported Visual Studio CMake generator")
            else
                configure()
            end
            os.vrunv("cmake", {"--build", ".", "--target", "install", "--config", configs.CMAKE_BUILD_TYPE, "-j", buildjobs}, {
                curdir = builddir,
                envs = {CMAKE_BUILD_PARALLEL_LEVEL = buildjobs}
            })
        end

        os.rm(srcdir)
        os.rm(buildroot)
        os.mkdir(buildroot)

        os.vrunv("git", {"clone", "--recursive", git_url, srcdir})
        os.vrunv("git", {"submodule", "update", "--init", "--recursive"}, {curdir = srcdir})
        apply_source_patches(srcdir)

        local orz_configs = table.join(common, {
            ORZ_INSTALL = "ON"
        })
        install_module("OpenRoleZoo", orz_configs)

        local authorize_configs = table.join(common, {
            ORZ_ROOT_DIR = cmake_installdir
        })
        install_module("SeetaAuthorize", authorize_configs)

        local tennis_configs = table.join(common, {
            TS_DYNAMIC_INSTRUCTION = "ON"
        })
        install_module("TenniS", tennis_configs)

        local sdk_configs = table.join(common, {
            ORZ_ROOT_DIR = cmake_installdir,
            SEETA_INSTALL_PATH = cmake_installdir,
            SEETA_AUTHORIZE = "OFF",
            SEETA_MODEL_ENCRYPT = "ON"
        })

        for _, modulename in ipairs({
            "FaceBoxes",
            "Landmarker",
            "FaceRecognizer6",
            "FaceTracker6",
            "FaceAntiSpoofingX6",
            "SeetaAgePredictor",
            "SeetaEyeStateDetector",
            "SeetaGenderPredictor",
            "SeetaMaskDetector",
            "PoseEstimator6",
            "QualityAssessor3"
        }) do
            install_module(modulename, sdk_configs)
        end
        end
    )

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("include"), "seeta", "FaceRecognizer.h")), "seetaface headers not found")
    end)
