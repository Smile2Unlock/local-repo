package("slint")
    set_homepage("https://slint.dev")
    set_description("Slint C++ SDK for building native user interfaces")
    set_license("GPL-3.0-only OR LicenseRef-Slint-Royalty-Free-2.0 OR LicenseRef-Slint-Software-3.0")

    if is_plat("linux") and is_arch("x86_64") then
        add_urls("https://github.com/slint-ui/slint/releases/download/$(version)/Slint-cpp-1.17.0-Linux-x86_64.tar.gz")
        add_versions("v1.17.0", "4de40322dee9c425d95f30f76219522a181001477d0e9c6dd2c7d72fc7894224")
    end

    on_load(function (package)
        package:set("kind", "library")
        package:add("links", "slint_cpp")
    end)

    on_install(function (package)
        os.cp("*", package:installdir())
    end)

    on_fetch(function (package)
        local installdir = package:installdir()
        local includedir = path.join(installdir, "include")
        local libdir = path.join(installdir, "lib")
        local bindir = path.join(installdir, "bin")

        if not os.isdir(includedir) or not os.isdir(libdir) then
            return nil
        end

        local links = {}
        for _, candidate in ipairs({"slint_cpp", "slint"}) do
            if os.isfile(path.join(libdir, "lib" .. candidate .. ".a"))
                or os.isfile(path.join(libdir, "lib" .. candidate .. ".so"))
                or os.isfile(path.join(libdir, candidate .. ".lib")) then
                table.insert(links, candidate)
            end
        end

        if #links == 0 then
            return nil
        end

        return {
            links = links,
            linkdirs = {libdir},
            includedirs = {includedir},
            bindirs = {bindir}
        }
    end)

    on_test(function (package)
        assert(os.isdir(path.join(package:installdir(), "include")), "Slint include directory not found")
        assert(os.isdir(path.join(package:installdir(), "lib")), "Slint lib directory not found")
    end)
