package("papiliocharontis")
    set_homepage("https://github.com/HenryAWE/PapilioCharontis")
    set_description("A flexible C++ formatting library for internationalization (i18n)")
    set_license("MIT")

    add_urls("https://github.com/HenryAWE/PapilioCharontis/archive/refs/tags/$(version).tar.gz",
             "https://github.com/HenryAWE/PapilioCharontis.git", {submodules = false})

    add_versions("v1.1.0", "23a08eedddc4369db6053955684bc7b1eac122486cacfe6a21990081950fe0c6")

    add_configs("unit_test", {description = "Build unit tests.", default = false, type = "boolean"})
    add_configs("example", {description = "Build examples.", default = false, type = "boolean"})
    add_configs("module", {description = "Build C++20 modules (experimental).", default = false, type = "boolean"})
    add_configs("shared", {description = "Build shared library.", default = false, type = "boolean"})

    add_deps("cmake")

    on_load(function (package)
        package:set("kind", "library")
        package:add("links", "papilio")
    end)

    on_fetch(function (package)
        local includedir = package:installdir("include")
        local libdir = package:installdir("lib")
        local bindir = package:installdir("bin")
        local marker = path.join(includedir, "papilio", "papilio.hpp")
        local libfile = path.join(libdir, "libpapilio.a")
        local sharedfile = path.join(libdir, "libpapilio.so")
        local dylibfile = path.join(libdir, "libpapilio.dylib")
        local winlibfile = path.join(libdir, "papilio.lib")
        local dllfile = path.join(bindir, "papilio.dll")

        if not os.isfile(marker)
            or (not os.isfile(libfile)
                and not os.isfile(sharedfile)
                and not os.isfile(dylibfile)
                and not os.isfile(winlibfile)
                and not os.isfile(dllfile)) then
            return nil
        end

        return {
            links = {"papilio"},
            linkdirs = {libdir},
            bindirs = {bindir},
            includedirs = {includedir}
        }
    end)

    on_install(function (package)
        local configs = {
            "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"),
            "-Dpapilio_build_lib=ON",
            "-Dpapilio_build_example=OFF",
            "-Dpapilio_build_unit_test=OFF",
            "-Dpapilio_build_module=OFF",
            "-Dpapilio_build_doc=OFF",
            "-Dpapilio_all_warnings=OFF",
            "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"),
        }
        import("package.tools.cmake").install(package, configs)

        local installdir = package:installdir()
        local includedir = path.join(installdir, "include")
        local libdir = path.join(installdir, "lib")
        local bindir = path.join(installdir, "bin")

        assert(os.isfile(path.join(includedir, "papilio", "papilio.hpp")),
            "papiliocharontis package: installed headers are missing")
        assert(os.isfile(path.join(libdir, "libpapilio.a"))
            or os.isfile(path.join(libdir, "papilio.lib"))
            or os.isfile(path.join(libdir, "libpapilio.so"))
            or os.isfile(path.join(libdir, "libpapilio.dylib"))
            or os.isfile(path.join(bindir, "papilio.dll")),
            "papiliocharontis package: installed library artifact is missing")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libpapilio.a"))
            or os.isfile(path.join(package:installdir("lib"), "papilio.lib"))
            or os.isfile(path.join(package:installdir("lib"), "libpapilio.so"))
            or os.isfile(path.join(package:installdir("lib"), "libpapilio.dylib"))
            or os.isfile(path.join(package:installdir("bin"), "papilio.dll")),
            "papiliocharontis library artifact not found")
        assert(os.isdir(path.join(package:installdir("include"), "papilio")), "papiliocharontis include directory not found")
    end)
