package("SeetaFace6Open")
    set_homepage("https://github.com/SeetaFace6Open/index")
    set_description("SeetaFace6Open built from upstream source")
    set_license("BSD-2-Clause")

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

    local function _build_configs(package)
        local buildtype = package:is_debug() and "Debug" or "Release"
        local platform = package:is_arch("x86", "i386") and "x86" or "x64"
        local installdir = package:installdir()
        local cmake_installdir = path.unix(installdir)
        local cc = package:build_getenv("cc")
        local cxx = package:build_getenv("cxx")
        return buildtype, platform, installdir, {
            CMAKE_BUILD_TYPE = buildtype,
            CONFIGURATION = buildtype,
            PLATFORM = platform,
            TARGET = "SHARED",
            CMAKE_POLICY_VERSION_MINIMUM = "3.10",
            CMAKE_INSTALL_PREFIX = cmake_installdir,
            CMAKE_PREFIX_PATH = cmake_installdir,
            CMAKE_MODULE_PATH = path.unix(path.join(installdir, "cmake")),
            CMAKE_C_COMPILER = cc and path.unix(cc) or nil,
            CMAKE_CXX_COMPILER = cxx and path.unix(cxx) or nil
        }
    end

    local function _msvc_cmake_generators()
        return {
            "Visual Studio 18 2026",
            "Visual Studio 17 2022",
            "Visual Studio 16 2019",
            "Visual Studio 15 2017"
        }
    end

    on_load(function (package)
        package:add("links", table.unpack(_package_links(package)))
    end)

    on_fetch(function (package)
        local archdir = _package_archdir(package)
        local result = {}
        result.links = _package_links(package)
        result.linkdirs = package:installdir(path.join("lib", archdir))
        result.includedirs = package:installdir("include")
        result.bindirs = package:installdir(path.join("bin", archdir))
        return result
    end)

    on_install("windows|x64", "windows|x86", "mingw|x86_64", "mingw|i386", function (package)
        local function apply_source_patches(srcdir)
            local pot_h = path.join(srcdir, "OpenRoleZoo", "include", "orz", "mem", "pot.h")
            if os.isfile(pot_h) then
                local content = io.readfile(pot_h)
                if content and not content:find("#include <functional>", 1, true) then
                    content = content:gsub("#include <memory>", "#include <memory>\n#include <functional>", 1)
                    io.writefile(pot_h, content)
                end
            end
        end

        local git_url = "https://github.com/SeetaFace6Open/index.git"
        local srcdir = path.join(package:installdir(), "src")
        local buildroot = path.join(package:installdir(), "buildtrees")
        local _, platform, installdir, common = _build_configs(package)
        local cmake_installdir = path.unix(installdir)
        local is_msvc = package:is_plat("windows")
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
                    table.insert(argv, "-A")
                    table.insert(argv, platform == "x86" and "Win32" or "x64")
                else
                    table.insert(argv, "-G")
                    table.insert(argv, "Ninja")
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
            os.vrunv("cmake", {"--build", ".", "--target", "install", "--config", configs.CMAKE_BUILD_TYPE, "-j", "8"}, {curdir = builddir})
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
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("include"), "seeta", "FaceRecognizer.h")), "seetaface headers not found")
    end)
