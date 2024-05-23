local utils = require("utils")
local array = require("array")

----- BEGIN CONFIGURATION
local LUA_VERSION = "5.4"
local LUA_EXENAME = "lua.exe"
local LUAC_EXENAME = "luac.exe"

local LUA_LIBNAME = "lua54.lib"
local LUA_DLLNAME = "lua54.dll"

local INSTALL_TOP = "./build"
local INSTALL_BIN = INSTALL_TOP .. "/bin"
local INSTALL_INC = INSTALL_TOP .. "/include"
local INSTALL_LIB = INSTALL_TOP .. "/lib"

local BUILD_AS_DLL = false
local LTO = true
local LINUX = false

local CC = "gcc"
local CFLAGS = {
    "-O3", 
    "-DLUA_COMPAT_5_3", 

    utils.blank_if_not(BUILD_AS_DLL, "-DLUA_BUILD_AS_DLL"), 
    utils.blank_if_not(LINUX, "-DLUA_USE_LINUX"), 
    utils.blank_if_not(LINUX, "-DLUA_USE_READLINE") 
}
local LINKFLAGS = { 
    utils.blank_if_not(LINUX, "-lm"), 
    utils.blank_if_not(LINUX, "-ldl"), 
    utils.blank_if_not(LINUX, "-lreadline") 
}

------ END OF CONFIGURATION

-- Parse Makefile
local source_files = array:new({})
local source_makefile = "src/Makefile"
source_files:push_array(utils.parse_makefile(source_makefile, "CORE_O"):map(function(file) return utils.sourceify(file) end))
source_files:push_array(utils.parse_makefile(source_makefile, "LIB_O"):map(function(file) return utils.sourceify(file) end))

if arg[1] == "clean" then 
    utils.clean_up_artifacts()
    utils.clean_up_objects(source_files)
    print("Done")
    os.exit(1)
end

if (LINUX or utils.exists("/dev/null")) and BUILD_AS_DLL then 
    print("ERROR: Cannot build in DLL mode in a Linux environment.")
    os.exit(1)
end

if (LINUX and os.getenv("WINDIR")) then 
    print("ERROR: Cannot build in Linux mode in a Windows environment.")
    os.exit(1)
end

-- VARIABLES
local source_files = array:new({})

-- Lua 5.1 luac hack

if utils.exists("src/print.c") then 
    source_files:push("print.c")
end

-- helper functions
local function build_object_files(lto)
    source_files:for_each(function(file)
        local out_file = utils.objectify(lto and utils.lto_prefix(file) or file)
        if not utils.exists("src/" .. out_file) then
            utils.run(CC, utils.concat(CFLAGS, { utils.blank_if_not(lto, "-flto"), "-c", "-o", out_file, file }))
        else
            utils.printf("Skipping compilation of already-compiled object %s\n", out_file)
        end
    end)
end

local function build_static_library()
    build_object_files(false)
    utils.run("ar", utils.concat(
        { "rcs", LUA_LIBNAME }, 
        source_files:map(function(file) return utils.objectify(file) end)
    ))
end

local function build_static_library_lto()
    build_object_files(true)
    utils.run("ar", utils.concat(
        { "rcs", utils.lto_prefix(LUA_LIBNAME) }, 
        source_files:map(function(file) return utils.objectify(utils.lto_prefix(file)) end)
    ))
end

local function build_dynamic_library()
    build_object_files(false)
    utils.run(CC, utils.concat(
        { "-s", "-shared", "-o", LUA_DLLNAME }, 
        source_files:map(function(file) return utils.objectify(file) end), 
        LINKFLAGS
    ))
end

local function build_dynamic_library_lto()
    build_object_files(true)
    utils.run(CC, utils.concat(
        { "-s", "-shared", "-o", LUA_DLLNAME }, 
        source_files:map(function(file) return utils.objectify(utils.lto_prefix(file)) end), 
        LINKFLAGS
    ))
end

local function build_static()
    build_static_library()
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUA_EXENAME, "lua.c", LUA_LIBNAME }, LINKFLAGS))
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUAC_EXENAME, "luac.c", LUA_LIBNAME }, LINKFLAGS))
end

local function build_dynamic()
    build_dynamic_library()
    build_static_library()
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUA_EXENAME, "lua.c", LUA_DLLNAME }, LINKFLAGS))
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUAC_EXENAME, "luac.c", LUA_LIBNAME }, LINKFLAGS))
    os.remove("src/" .. LUA_LIBNAME)
end

local function build_lto_static()
    build_static_library_lto()
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUA_EXENAME, "lua.c", utils.lto_prefix(LUA_LIBNAME) }, LINKFLAGS))
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUAC_EXENAME, "luac.c", utils.lto_prefix(LUA_LIBNAME) }, LINKFLAGS))
    build_static_library()
end

local function build_lto_dynamic()
    build_dynamic_library_lto()
    build_static_library_lto()
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUA_EXENAME, "lua.c", LUA_DLLNAME }, LINKFLAGS))
    utils.run(CC, utils.concat(CFLAGS, { "-s", "-o", LUAC_EXENAME, "luac.c", utils.lto_prefix(LUA_LIBNAME) }, LINKFLAGS))
    os.remove("src/" .. utils.lto_prefix(LUA_LIBNAME))
end

utils.clean_up_artifacts()
utils.clean_up_objects(source_files)
utils.move("src")

utils.printf("Build mode: %s\n", BUILD_AS_DLL and "dynamic" or "static")
utils.printf("LTO: %s\n", LTO and "ON" or "OFF")
utils.printf("Confirm settings? [Y/n]: ")
if string.lower(io.stdin:read("*l")) ~= "y" then
    print("Quitting.")
    os.exit(1)
end

if BUILD_AS_DLL then
    if LTO then
        build_lto_dynamic()
    else
        build_dynamic()
    end
    utils.run("gendef", { LUA_DLLNAME })
    utils.run("dlltool", { "-d", utils.switch_ext(LUA_DLLNAME, "def"), "-m", "i386:x86-64", "-l", LUA_LIBNAME })
    os.remove("src/" .. utils.switch_ext(LUA_DLLNAME, "def"))
else
    if LTO then
        build_lto_static()
    else
        build_static()
    end
end

-- Installation
utils.move(".")
utils.printf("Installation directory: %s\n", INSTALL_TOP)
utils.printf("Proceed with installation? [Y/n]: ")
if string.lower(io.stdin:read("*l")) ~= "y" then
    print("Quitting.")
    os.exit(1)
end
utils.run("install", { "-d", INSTALL_BIN })
utils.run("install", { "-d", INSTALL_INC })
utils.run("install", { "-d", INSTALL_LIB })

-- From Lua 5.3 and on, INSTALL_TOP/share/lua/5.x and INSTALL_TOP/library/lua/5.x
-- are part of PATH and CPATH
-- For earlier versions you can manually add them
utils.run("install", { "-d", INSTALL_TOP .. "/share/lua/" .. LUA_VERSION })
utils.run("install", { "-d", INSTALL_TOP .. "/lib/lua/" .. LUA_VERSION })

utils.run("install", { "src/" .. LUA_EXENAME, INSTALL_BIN })
utils.run("install", { "src/" .. LUAC_EXENAME, INSTALL_BIN })
if BUILD_AS_DLL then utils.run("install", { "src/" .. LUA_DLLNAME, INSTALL_BIN }) end

utils.parse_makefile("Makefile", "TO_INC"):for_each(function(file) 
    utils.run("install", { "src/" .. file, INSTALL_INC })
end)

utils.run("install", { "src/" .. LUA_LIBNAME, INSTALL_LIB })
if LTO and not BUILD_AS_DLL then
    utils.run("install", { "src/" .. utils.lto_prefix(LUA_LIBNAME), INSTALL_LIB })
end