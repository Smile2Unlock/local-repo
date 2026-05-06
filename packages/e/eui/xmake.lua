package("eui")
    set_homepage("https://github.com/sudoevolve/EUI-NEO")
    set_description("EUI-NEO: a cross-platform, high-performance, low-overhead C++17 UI framework built on OpenGL and GLFW")
    set_license("MIT")

    add_deps("cmake")

    on_load(function (package)
        package:add("links", "eui_neo_core")
    end)

    on_install(function (package)
        local installdir = package:installdir()
        local srcdir = path.join(os.projectdir(), ".xmake", "EUI-NEO-0.3.6")
        local builddir = path.absolute(package:builddir())
        local includedir = path.join(installdir, "include")
        local eui_includedir = path.join(includedir, "eui")
        local libdir = path.join(installdir, "lib")

        assert(os.isdir(srcdir), "eui package: source directory not found at " .. srcdir)
        assert(os.isdir(path.join(srcdir, "core")), "eui package: missing core directory in " .. srcdir)

        os.mkdir(includedir)
        os.mkdir(eui_includedir)
        os.mkdir(libdir)

        -- 复制自定义 CMakeLists.txt 到源码目录覆盖原有的（原版只编译 demo，没有库目标）
        local cmakelists = path.join(os.projectdir(), "local-repo", "packages", "e", "eui", "CMakeLists.txt")
        assert(os.isfile(cmakelists), "eui package: missing custom CMakeLists.txt at " .. cmakelists)
        os.vcp(cmakelists, path.join(srcdir, "CMakeLists.txt"))

        -- Configure cmake
        local configs = {
            CMAKE_BUILD_TYPE = package:is_debug() and "Debug" or "Release",
            CMAKE_INSTALL_PREFIX = path.unix(installdir),
            BUILD_SHARED_LIBS = "OFF"
        }

        local cc = package:build_getenv("cc")
        local cxx = package:build_getenv("cxx")
        if cc then configs.CMAKE_C_COMPILER = cc end
        if cxx then configs.CMAKE_CXX_COMPILER = cxx end

        os.mkdir(builddir)
        local argv = {}
        for name, value in pairs(configs) do
            table.insert(argv, "-D" .. name .. "=" .. value)
        end
        table.insert(argv, path.unix(srcdir))
        os.vrunv("cmake", argv, {curdir = builddir})

        -- Build eui_neo_core static library
        local njobs = tostring(os.default_njob() or 8)
        os.vrunv("cmake", {"--build", ".", "--target", "eui_neo_core", "--config", configs.CMAKE_BUILD_TYPE, "-j", njobs}, {
            curdir = builddir,
            envs = {CMAKE_BUILD_PARALLEL_LEVEL = njobs}
        })

        -- 复制头文件：v0.3.6 没有 src/ 前缀，目录结构为 core/ components/ app/ 3rd/
        local src_root = srcdir
        assert(os.isdir(path.join(src_root, "core")), "eui package: missing core directory")

        for _, dirname in ipairs({"core", "components", "app", "3rd"}) do
            local dirpath = path.join(src_root, dirname)
            if os.isdir(dirpath) then
                os.vcp(dirpath, path.join(eui_includedir, dirname))
            end
        end

        -- 复制内置的第三方单头文件（如 stb、nanosvg）
        local third_dir = path.join(src_root, "3rd")
        if os.isdir(third_dir) then
            for _, header in ipairs(os.files(path.join(third_dir, "*.h"))) do
                os.vcp(header, path.join(eui_includedir, "3rd", path.filename(header)))
            end
        end

        -- 验证核心头文件已复制
        assert(os.isfile(path.join(eui_includedir, "core", "dsl.h")),
            "eui package: failed to copy core/dsl.h into include/eui/core")
        assert(os.isfile(path.join(eui_includedir, "components", "components.h")),
            "eui package: failed to copy components/components.h into include/eui/components")

        -- 查找构建好的静态库
        local function find_lib(name)
            -- 先在根目录找
            local root_file = path.join(builddir, name)
            if os.isfile(root_file) then
                return root_file
            end
            -- 再递归查找
            for _, filepath in ipairs(os.files(path.join(builddir, "**/" .. name))) do
                if os.isfile(filepath) then
                    return filepath
                end
            end
            return nil
        end

        local libname = package:is_plat("windows") and "eui_neo_core.lib" or "libeui_neo_core.a"
        local libfile = find_lib(libname)
        if not libfile then
            for _, alt in ipairs({"libeui_neo_core.a", "eui_neo_core.lib", "libeui_neo_core.so", "libeui_neo_core.dylib"}) do
                libfile = find_lib(alt)
                if libfile then
                    os.cp(libfile, path.join(libdir, alt))
                    break
                end
            end
        else
            os.cp(libfile, path.join(libdir, libname))
        end

        if not libfile then
            raise("eui package: failed to locate built eui_neo_core library artifact in " .. builddir)
        end
    end)

    on_fetch(function (package)
        local installdir = package:installdir()
        local includedir = path.join(installdir, "include")
        local libdir = path.join(installdir, "lib")
        local marker = path.join(includedir, "eui", "core", "dsl.h")
        local libfile = path.join(libdir, "libeui_neo_core.a")
        local sharedfile = path.join(libdir, "libeui_neo_core.so")
        local dylibfile = path.join(libdir, "libeui_neo_core.dylib")
        local winlibfile = path.join(libdir, "eui_neo_core.lib")

        if not os.isfile(marker)
            or (not os.isfile(libfile)
                and not os.isfile(sharedfile)
                and not os.isfile(dylibfile)
                and not os.isfile(winlibfile)) then
            return nil
        end

        local includedirs = {includedir, path.join(includedir, "eui")}
        if os.isdir(path.join(includedir, "eui", "3rd")) then
            table.insert(includedirs, path.join(includedir, "eui", "3rd"))
        end

        return {
            links = {"eui_neo_core"},
            linkdirs = {libdir},
            includedirs = includedirs,
        }
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libeui_neo_core.a"))
            or os.isfile(path.join(package:installdir("lib"), "eui_neo_core.lib"))
            or os.isfile(path.join(package:installdir("lib"), "libeui_neo_core.so"))
            or os.isfile(path.join(package:installdir("lib"), "libeui_neo_core.dylib")),
            "eui package: installed core library artifact is missing")
    end)
