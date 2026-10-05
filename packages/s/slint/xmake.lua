package("slint")
    set_homepage("https://slint.dev")
    set_description("Slint C++ SDK for building native user interfaces")
    set_license("GPL-3.0-only OR LicenseRef-Slint-Royalty-Free-2.0 OR LicenseRef-Slint-Software-3.0")

    if is_plat("linux") and is_arch("x86_64") then
        add_urls("https://github.com/Smile2Unlock/local-repo/releases/download/slint-prebuilt-$(version)/Slint-cpp-1.18.1-Linux-x86_64.tar.gz")
        add_versions("v1.18.1", "f0b24ea601b80afe241677d1179bf5215dceae529f2b275b678a0af9a144b255")
    elseif is_plat("mingw") and is_arch("x86_64") and is_host("linux") then
        -- mingw 交叉构建：从源码构建（host 编译器 + windows-gnu 目标运行时）
        add_urls("https://github.com/slint-ui/slint/archive/refs/tags/$(version).tar.gz")
        add_versions("v1.18.1", "fe485305ed303215e76c04918ee9aefbffbe229f18f979098ec36c7fa1dab28b")
        add_deps("cmake", "ninja")
    end

    on_load(function (package)
        package:set("kind", "library")
        package:add("links", "slint_cpp")
        if package:is_plat("mingw") then
            package:add("syslinks", "uxtheme")
        end
    end)

    on_install(function (package)
        if not (is_plat("mingw") and is_host("linux")) then
            os.cp("*", package:installdir())
            return
        end

        local builddir = package:builddir()
        local host_target_dir = path.absolute(path.join(builddir, "cargo-target-host"))
        local win_target_dir = path.absolute(path.join(builddir, "cargo-target-win"))

        -- Host slint-compiler: runs at build time to translate .slint -> C++
        os.execv("cargo", {
            "build", "--locked", "--release", "-p", "slint-compiler",
            "--target-dir", host_target_dir
        }, {envs = {RUSTUP_TOOLCHAIN = "1.99.0"}})

        -- Windows runtime: staticlib consumed by mingw C++ targets.
        -- renderer-software enables SLINT_BACKEND=winit-software so the GUI can
        -- run without a GPU/OpenGL driver (e.g. inside a KVM VM).
        os.execv("cargo", {
            "build", "--locked", "--release", "--target", "x86_64-pc-windows-gnu", "-p", "slint-cpp",
            "--features", "renderer-software",
            "--target-dir", win_target_dir
        }, {envs = {RUSTUP_TOOLCHAIN = "1.99.0"}})

        local installdir = package:installdir()

        -- Headers: handwritten api/cpp/include plus cbindgen-generated private ones.
        -- os.cp glob does not recurse into subdirectories, so copy the private/
        -- directory explicitly (directory copies recurse).
        os.mkdir(path.join(installdir, "include", "slint"))
        os.cp(path.join("api", "cpp", "include", "*"), path.join(installdir, "include", "slint"))
        os.cp(path.join("api", "cpp", "include", "private"),
              path.join(installdir, "include", "slint", "private"))
        local generated = path.join(win_target_dir, "x86_64-pc-windows-gnu", "release", "build")
        for _, dir in ipairs(os.dirs(path.join(generated, "slint-cpp-*"))) do
            os.cp(path.join(dir, "out", "generated_include", "*"), path.join(installdir, "include", "slint"))
        end

        -- Static library
        os.mkdir(path.join(installdir, "lib"))
        os.cp(path.join(win_target_dir, "x86_64-pc-windows-gnu", "release", "libslint_cpp.a"),
              path.join(installdir, "lib"))

        -- We ship the static libslint_cpp.a. The config header marks all API
        -- externals dllimport on _WIN32 (upstream ships DLLs only), which would
        -- emit __imp_ prefixed symbols and fail to link. Neutralize it.
        -- (both the _MSC_VER branch and the __GNUC__/_WIN32 branch; the
        -- generated headers live in private/ and include "private/slint_config.h"
        -- relative to themselves, so the nested copy must be patched too)
        local config_headers = {
            path.join(installdir, "include", "slint", "private", "slint_config.h"),
            path.join(installdir, "include", "slint", "private", "private", "slint_config.h"),
        }
        for _, config_header in ipairs(config_headers) do
            if os.isfile(config_header) then
                io.replace(config_header,
                           [[#        define SLINT_DLL_IMPORT __declspec(dllimport)]],
                           [[#        define SLINT_DLL_IMPORT]],
                           { plain = true })
                io.replace(config_header,
                           [[#            define SLINT_DLL_IMPORT __declspec(dllimport)]],
                           [[#            define SLINT_DLL_IMPORT]],
                           { plain = true })
            end
        end

        -- Host compiler for the project's before_build step
        os.mkdir(path.join(installdir, "bin"))
        os.cp(path.join(host_target_dir, "release", "slint-compiler"), path.join(installdir, "bin"))

        -- Licenses
        os.cp("LICENSE.md", installdir)
        if os.isdir("LICENSES") then
            os.cp("LICENSES", installdir)
        else
            os.cp("licenses", installdir)
        end

        -- xmake auto-generates lib/pkgconfig/<name>.pc for library packages;
        -- the directory must exist or the write fails with ENOTDIR.
        os.mkdir(path.join(installdir, "lib", "pkgconfig"))
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
            -- Slint's Winit backend uses SetWindowTheme on Windows.
            syslinks = package:is_plat("mingw") and {"uxtheme"} or {},
            linkdirs = {libdir},
            includedirs = {includedir, path.join(includedir, "slint")},
            bindirs = {bindir}
        }
    end)

    on_test(function (package)
        assert(os.isdir(path.join(package:installdir(), "include")), "Slint include directory not found")
        assert(os.isdir(path.join(package:installdir(), "lib")), "Slint lib directory not found")
    end)
