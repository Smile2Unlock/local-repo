package("reflect-cpp")
    set_homepage("https://github.com/getml/reflect-cpp")
    set_description("A C++20 library for fast serialization, deserialization and validation using reflection")
    set_license("MIT")

    add_urls("https://github.com/getml/reflect-cpp/archive/refs/tags/$(version).tar.gz",
             "https://github.com/getml/reflect-cpp.git", {submodules = false})

    add_versions("v0.24.0", "2185d45cca58f60bcdaca37a995c6f8e90c0105f312610333fed75f2efa6a996")
    add_versions("v0.22.0", "5756d74e7df640b4633a3ea5a3c0d7c4e096bdd3f67828f8b02f58b156ba39ec")
    add_versions("v0.20.0", "b774f11fd602683e3c7febabfe6e888b866cec28497c5e9c6ba82aeeb4465bbc")
    add_versions("v0.19.0", "aad9e010a0e716ecf643a95cec2047c74ce4311accfe42b4cf888672267ab8cd")
    add_versions("v0.18.0", "c8df46550d787105ce695ea8f99425dc47475f5377c5253d412dd63f622dc7c7")
    add_versions("v0.17.0", "08b6406cbe4c6c14ff1a619fe93a94f92f6d9eb22213d93529ad975993945e45")
    add_versions("v0.16.0", "a84d94dbd353d788926d6e54507b44c046863f7bc4ecb35afe0338374a68a77d")
    add_versions("v0.14.1", "639aec9d33025703a58d32c231ab1ab474c0cc4fb0ff90eadcaffb49271c41cd")
    add_versions("v0.14.0", "ea92a2460a71184b7d4fa4e9baad9910efad092df78b114459a7d6b0ee558d3c")
    add_versions("v0.13.0", "a7a31832fe8bbaa7f7299da46dfd4ccc8b99a13242e16a1d93f8669de1fca9c6")
    add_versions("v0.12.0", "13d448dd5eaee13ecb7ab5cb61cb263c7111ba75230503adc823a888f68e1eaa")
    add_versions("v0.11.1", "e45f112fb3f14507a4aa53b99ae2d4ab6a4e7b2d5f04dd06fec00bf7faa7bbdc")
    add_versions("v0.10.0", "d2c8876d993ddc8c57c5804e767786bdb46a2bdf1a6cd81f4b14f57b1552dfd7")

    add_configs("bson", {description = "Enable BSON support.", default = false, type = "boolean", readonly = true})
    add_configs("yyjson", {description = "Enable yyjson support.", default = true, type = "boolean"})
    add_configs("cbor", {description = "Enable CBOR support.", default = false, type = "boolean"})
    add_configs("capnproto", {description = "Enable Capnproto support.", default = false, type = "boolean"})
    add_configs("flatbuffers", {description = "Enable Flexbuffers support.", default = false, type = "boolean"})
    add_configs("msgpack", {description = "Enable Msgpack support.", default = false, type = "boolean"})
    add_configs("xml", {description = "Enable XML support.", default = false, type = "boolean"})
    add_configs("toml", {description = "Enable TOML support.", default = true, type = "boolean"})
    add_configs("yaml", {description = "Enable YAML support.", default = false, type = "boolean"})
    add_configs("ubjson", {description = "Enable UBJSON support.", default = false, type = "boolean"})
    add_configs("shared", {description = "Build shared library.", default = false, type = "boolean"})

    on_check(function (package)
        if package:is_plat("windows") then
            local vs = package:toolchain("msvc"):config("vs")
            assert(vs and tonumber(vs) >= 2022, "package(reflect-cpp): need vs >= 2022")
        else
            assert(package:check_cxxsnippets({test = [[
                #include <ranges>
                #include <source_location>
                #include <iostream>
                #include <string_view>
                #include <cctype>
                void test() {
                    constexpr std::string_view message = "Hello, C++20!";
                    for (char c : std::views::filter(message, [](char ch) { return std::islower(static_cast<unsigned char>(ch)); })) {
                        std::cout << std::source_location::current().line() << ": " << c << '\n';
                    }
                }
            ]]}, {configs = {languages = "c++20"}}), "package(reflect-cpp): requires at least C++20.")
        end

        if package:config("capnproto") and package:version() and package:version():le("0.16.0") then
            raise("package(reflect-cpp): capnproto is not supported for version 0.16.0 and below.")
        end
    end)

    on_load(function (package)
        local version = package:version()

        if package:config("yyjson") then
            package:add("deps", "yyjson")
        end
        if package:config("cbor") then
            package:add("deps", "tinycbor")
        end
        if package:config("capnproto") then
            package:add("deps", "capnproto")
        end
        if package:config("flatbuffers") then
            package:add("deps", "flatbuffers")
        end
        if package:config("msgpack") then
            package:add("deps", "msgpack-c")
        end
        if package:config("xml") then
            package:add("deps", "pugixml")
        end
        if package:config("toml") then
            package:add("deps", "toml++")
        end
        if package:config("yaml") then
            package:add("deps", "yaml-cpp")
        end
        if package:config("ubjson") then
            package:add("deps", "jsoncons")
        end

        if version then
            if version:lt("0.13.0") then
                package:set("kind", "library", {headeronly = true})
            end
            if version:ge("0.11.1") then
                package:add("deps", "ctre", {configs = {cmake = true}})
                if version:eq("0.11.1") then
                    package:add("defines", "REFLECTCPP_NO_BUNDLED_DEPENDENCIES")
                end
            end
        end

        if package:gitref() or (version and (version:lt("0.11.1") or version:ge("0.13.0"))) then
            package:add("deps", "cmake")
        end
    end)

    on_install(function (package)
        local version = package:version()
        if package:gitref() or (version and (version:lt("0.11.1") or version:ge("0.13.0"))) then
            local configs = {
                "-DREFLECTCPP_USE_BUNDLED_DEPENDENCIES=OFF",
                "-DREFLECTCPP_USE_VCPKG=OFF",
                "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"),
                "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"),
                "-DREFLECTCPP_BSON=" .. (package:config("bson") and "ON" or "OFF"),
                "-DREFLECTCPP_CBOR=" .. (package:config("cbor") and "ON" or "OFF"),
                "-DREFLECTCPP_CAPNPROTO=" .. (package:config("capnproto") and "ON" or "OFF"),
                "-DREFLECTCPP_FLEXBUFFERS=" .. (package:config("flatbuffers") and "ON" or "OFF"),
                "-DREFLECTCPP_MSGPACK=" .. (package:config("msgpack") and "ON" or "OFF"),
                "-DREFLECTCPP_XML=" .. (package:config("xml") and "ON" or "OFF"),
                "-DREFLECTCPP_TOML=" .. (package:config("toml") and "ON" or "OFF"),
                "-DREFLECTCPP_UBJSON=" .. (package:config("ubjson") and "ON" or "OFF"),
                "-DREFLECTCPP_YAML=" .. (package:config("yaml") and "ON" or "OFF")
            }
            import("package.tools.cmake").install(package, configs)
        else
            os.rm("include/thirdparty")
            os.cp("include", package:installdir())
        end
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <rfl.hpp>
            #include <rfl/json.hpp>
            #include <rfl/DefaultIfMissing.hpp>
            struct Person {
                std::string first_name;
                std::string last_name;
                int age;
            };
            void test() {
                const auto homer = Person{.first_name = "Homer", .last_name = "Simpson", .age = 45};
                const std::string json_string = rfl::json::write(homer);
                auto homer2 = rfl::json::read<Person, rfl::DefaultIfMissing>(json_string).value();
                (void)homer2;
            }
        ]]}, {configs = {languages = "c++20"}}))

        if package:config("msgpack") then
            assert(package:check_cxxsnippets({test = [[
                #include <rfl.hpp>
                #include <rfl/msgpack.hpp>
                struct Person {
                    std::string first_name;
                    std::string last_name;
                    int age;
                };
                void test() {
                    const auto homer = Person{.first_name = "Homer", .last_name = "Simpson", .age = 45};
                    auto payload = rfl::msgpack::write(homer);
                    auto homer2 = rfl::msgpack::read<Person>(payload).value();
                    (void)homer2;
                }
            ]]}, {configs = {languages = "c++20"}}))
        end

        if package:config("capnproto") then
            assert(package:check_cxxsnippets({test = [[
                #include <rfl.hpp>
                #include <rfl/capnproto.hpp>
                struct Person {
                    std::string first_name;
                    std::string last_name;
                    int age;
                };
                void test() {
                    const auto homer = Person{.first_name = "Homer", .last_name = "Simpson", .age = 45};
                    auto payload = rfl::capnproto::write(homer);
                    auto homer2 = rfl::capnproto::read<Person>(payload).value();
                    (void)homer2;
                }
            ]]}, {configs = {languages = "c++20"}}))
        end
    end)
