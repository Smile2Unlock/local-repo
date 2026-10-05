set_project("local-repo SDK builder")
add_rules("mode.release")
add_repositories("local-repo " .. path.join(os.scriptdir(), "..", ".."))

if is_plat("mingw") then
    set_toolchains("mingw")
end

-- Rebuild the pinned SDK, including the Windows Unicode path patches.
add_requires("seetaface6open", {system = false,
    configs = {unicode_paths = true, prebuilt = false}})

target("sdk")
    set_kind("phony")
    add_packages("seetaface6open")
    on_build(function (target)
        local package = assert(target:pkg("seetaface6open"))
        print("Built SeetaFace SDK: " .. package:installdir())
    end)
