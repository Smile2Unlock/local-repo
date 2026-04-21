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
        if package:version() and package:version():ge("1.1.0") then
            package:set("kind", "library", {headeronly = true})
        end
    end)

    on_fetch(function (package)
        local result = {}
        result.includedirs = package:installdir("include")
        return result
    end)

    on_install(function (package)
        os.cp("include", package:installdir())
    end)

    on_test(function (package)
        assert(os.isdir(path.join(package:installdir("include"), "papilio")), "papiliocharontis include directory not found")
    end)
