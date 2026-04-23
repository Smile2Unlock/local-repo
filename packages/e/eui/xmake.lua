package("eui")
    set_homepage("https://github.com/sudoevolve/EUI")
    set_description("EUI core library packaged from the upstream CMake project")
    set_license("MIT")

    add_urls("https://github.com/sudoevolve/EUI.git")
    add_versions("df3f9b591920535789a34426422134a3e92b23b1", "df3f9b591920535789a34426422134a3e92b23b1")

    add_deps("cmake")

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

    local function _collect_includedirs(installdir)
        local includedirs = {}
        local include_root = path.join(installdir, "include")
        if os.isdir(include_root) then
            table.insert(includedirs, include_root)
            for _, subdir in ipairs(os.dirs(path.join(include_root, "*"))) do
                table.insert(includedirs, subdir)
            end
        end
        return includedirs
    end

    on_load(function (package)
        package:add("links", "eui_neo_core")
    end)

    on_install(function (package)
        local installdir = package:installdir()
        local srcdir = path.join(package:cachedir(), "source", "eui")
        local builddir = path.join(package:builddir(), "build")
        local includedir = path.join(installdir, "include")
        local eui_includedir = path.join(includedir, "eui")
        local libdir = path.join(installdir, "lib")
        local bindir = path.join(installdir, "bin")

        os.mkdir(includedir)
        os.mkdir(eui_includedir)
        os.mkdir(libdir)
        os.mkdir(bindir)

        local configs = {
            CMAKE_BUILD_TYPE = package:is_debug() and "Debug" or "Release"
        }

        local cc = _normalize_binpath(package:build_getenv("cc"))
        local cxx = _normalize_binpath(package:build_getenv("cxx"))
        if cc then
            configs.CMAKE_C_COMPILER = cc
        end
        if cxx then
            configs.CMAKE_CXX_COMPILER = cxx
        end

        import("package.tools.cmake").install(package, configs, {builddir = builddir, sourcedir = srcdir})

        local src_root = path.join(srcdir, "src")
        assert(os.isdir(src_root), "eui package: missing src directory: " .. src_root)

        for _, filename in ipairs({"EUINEO.h", "EUINEO.cpp"}) do
            local filepath = path.join(src_root, filename)
            if os.isfile(filepath) then
                os.vcp(filepath, path.join(eui_includedir, filename))
            end
        end

        for _, dirname in ipairs({"app", "components", "pages", "ui", "font"}) do
            local dirpath = path.join(src_root, dirname)
            if os.isdir(dirpath) then
                os.vcp(dirpath, path.join(eui_includedir, dirname))
            end
        end

        local third_party_root = path.join(srcdir, "third_party")
        if os.isdir(third_party_root) then
            for _, pattern in ipairs({"*.h", "*.hpp", "*.hh", "*.hxx"}) do
                for _, header in ipairs(os.files(path.join(third_party_root, pattern))) do
                    os.vcp(header, path.join(eui_includedir, path.filename(header)))
                end
            end
        end

        assert(os.isfile(path.join(eui_includedir, "EUINEO.h")),
            "eui package: failed to copy src headers into include/eui")
        assert(os.isfile(path.join(eui_includedir, "app", "DslAppRuntime.h")),
            "eui package: failed to copy src/app headers into include/eui/app")

        local function copy_if_exists(filepath, destdir)
            if os.isfile(filepath) then
                os.cp(filepath, destdir)
                return true
            end
            return false
        end

        local function copy_candidates(filenames, destdir)
            local copied = false
            for _, filename in ipairs(filenames) do
                copied = copy_if_exists(path.join(builddir, filename), destdir) or copied
                for _, filepath in ipairs(os.files(path.join(builddir, "**/" .. filename))) do
                    os.cp(filepath, destdir)
                    copied = true
                end
            end
            return copied
        end

        copy_candidates({"libeui_neo_core.a", "eui_neo_core.lib", "libeui_neo_core.so", "libeui_neo_core.dylib"}, libdir)
        copy_candidates({"eui_neo_core.dll"}, bindir)

        local found_lib = false
        for _, candidate in ipairs({
            path.join(libdir, "libeui_neo_core.a"),
            path.join(libdir, "eui_neo_core.lib"),
            path.join(libdir, "libeui_neo_core.so"),
            path.join(libdir, "libeui_neo_core.dylib"),
            path.join(bindir, "eui_neo_core.dll")
        }) do
            if os.isfile(candidate) then
                found_lib = true
                break
            end
        end

        if not found_lib then
            raise("eui package: failed to locate built eui_neo_core artifacts")
        end
    end)

    on_fetch(function (package)
        local result = {}
        result.links = {"eui_neo_core"}
        result.linkdirs = package:installdir("lib")
        result.includedirs = _collect_includedirs(package:installdir())
        result.bindirs = package:installdir("bin")
        return result
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libeui_neo_core.a"))
            or os.isfile(path.join(package:installdir("lib"), "eui_neo_core.lib"))
            or os.isfile(path.join(package:installdir("lib"), "libeui_neo_core.so"))
            or os.isfile(path.join(package:installdir("lib"), "libeui_neo_core.dylib"))
            or os.isfile(path.join(package:installdir("bin"), "eui_neo_core.dll")),
            "eui package: installed core library artifact is missing")
    end)
