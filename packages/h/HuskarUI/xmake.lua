package("HuskarUI")

    set_homepage("https://github.com/your-org/HuskarUI")
    set_description("A Qt-based C++ UI framework for Windows applications")
    set_license("MIT")

    -- 设置版本信息
    -- add_versions("0.4.9.1")

    -- 添加配置选项
    add_configs("shared", {description = "Build shared library.", default = true, type = "boolean"})
    add_configs("qt_version", {description = "Qt version to use", default = "6", values = {"5", "6"}})

    -- Windows平台特定的配置
    on_load("windows", function (package)
        -- 在on_load中动态添加Qt依赖
        local qt_version = package:config("qt_version") or "6"
        package:add("deps", "qt" .. qt_version .. "core", "qt" .. qt_version .. "qml")
        
        -- 设置包含目录
        package:add("includedirs", "include")
        package:add("includedirs", "include/controls")
        package:add("includedirs", "include/theme") 
        package:add("includedirs", "include/utils")
        
        -- 设置链接库
        package:add("links", "HuskarUIBasic")
        
        -- 设置库目录
        package:add("linkdirs", "lib")
        
        -- 设置运行时库路径
        package:addenv("PATH", "bin")
        
        -- 添加Qt相关的定义
        if not package:config("shared") then
            package:add("defines", "BUILD_HUSKARUI_STATIC_LIBRARY")
        end
        
        -- 添加Qt模块依赖
        package:add("defines", "QT_CORE_LIB", "QT_QML_LIB")
    end)

    -- Windows平台的安装处理（预编译包）
    on_install("windows", function (package)
        -- 对于预编译包，我们只需要确保目录结构正确
        local windowsdir = path.join(os.scriptdir(), package:plat())
        
        -- 验证关键文件是否存在
        local libfile = path.join(windowsdir, "lib", "HuskarUIBasic.lib")
        local dllfile = path.join(windowsdir, "bin", "HuskarUIBasic.dll")
        local headerfile = path.join(windowsdir, "include", "husapp.h")
        
        if not os.isfile(libfile) then
            raise("HuskarUI library file not found: " .. libfile)
        end
        
        if not os.isfile(dllfile) and package:config("shared") then
            raise("HuskarUI DLL file not found: " .. dllfile)
        end
        
        if not os.isfile(headerfile) then
            raise("HuskarUI header file not found: " .. headerfile)
        end
        
        print("HuskarUI Qt prebuilt package verified successfully")
    end)

    -- 包查找逻辑
    on_fetch("windows", function (package)
        local windowsdir = path.join(os.scriptdir(), package:plat())
        
        -- 检查关键文件是否存在
        local libfile = path.join(windowsdir, "lib", "HuskarUIBasic.lib")
        local headerfile = path.join(windowsdir, "include", "husapp.h")
        
        if not os.isfile(libfile) or not os.isfile(headerfile) then
            return nil  -- 返回nil让xmake执行on_install
        end
        
        -- 返回包配置信息
        local result = {}
        result.links = {"HuskarUIBasic"}
        result.linkdirs = {path.join(windowsdir, "lib")}
        result.includedirs = {
            path.join(windowsdir, "include"),
            path.join(windowsdir, "include/controls"),
            path.join(windowsdir, "include/theme"),
            path.join(windowsdir, "include/utils")
        }
        
        -- 添加Qt相关的定义
        result.defines = {"QT_CORE_LIB", "QT_QML_LIB"}
        if not package:config("shared") then
            table.insert(result.defines, "BUILD_HUSKARUI_STATIC_LIBRARY")
        end
        
        -- 如果是动态链接，添加DLL路径到运行时环境
        if package:config("shared") then
            package:addenv("PATH", path.join(windowsdir, "bin"))
        end
        
        return result
    end)

    -- 测试函数，验证包是否正常工作
    on_test(function (package)
        -- 简单的编译测试，包含Qt头文件
        assert(package:check_cxxsnippets({test = [[
            #include <QtCore/QObject>
            #include <QtQml/QQmlEngine>
            #include "husapp.h"
            #include "husdefinitions.h"
            #include "husglobal.h"
            
            void test_huskarui() {
                // 验证Qt和HuskarUI头文件包含正常
                QQmlEngine* engine = nullptr;
                Huskar::HusApp* app = Huskar::HusApp::instance();
                
                // 验证Qt宏定义
                Q_UNUSED(engine);
                Q_UNUSED(app);
            }
        ]]}, {
            configs = {languages = "c++17"}, 
            includes = {
                "husapp.h", 
                "husdefinitions.h", 
                "husglobal.h",
                "QtCore/QObject",
                "QtQml/QQmlEngine"
            },
            defines = {"QT_CORE_LIB", "QT_QML_LIB"}
        }))
        
        print("HuskarUI Qt package test passed!")
    end)