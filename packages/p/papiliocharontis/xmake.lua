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
        package:add("links", "papilio")
    end)

    on_fetch(function (package)
        local result = {}
        result.links = {"papilio"}
        result.linkdirs = package:installdir("lib")
        result.bindirs = package:installdir("bin")
        result.includedirs = package:installdir("include")
        return result
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
