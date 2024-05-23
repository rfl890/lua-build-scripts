local array = require("array")
local unpack = table.unpack or unpack

local function printf(fmt, ...) 
    io.stderr:write(string.format(fmt, ...))
end
local cwd = "."

local function move(dir) 
    cwd = dir
end

local function run(command, args) 
    local command = { command, unpack(args) }
    local full_command = { "cd", cwd, "&&", unpack(command) }
    print(table.concat(command, " "))
    os.execute(table.concat(full_command, " "))
end

local function starts(str, start)
    if (str:sub(1, #start) == start) then return true end
end

local function split(str, pattern)
    local result = {}
    for s in string.gmatch(str, "([^" .. pattern .. "]+)") do
        table.insert(result, s)
    end
    return result
end

local function lto_prefix(file) 
    local splitted = split(file, ".")
    splitted[1] = splitted[1] .. "-lto"
    return table.concat(splitted, ".")
end
local function objectify(file)
    local splitted = split(file, ".")
    splitted[#splitted] = "obj"
    return table.concat(splitted, ".")
end
local function sourceify(file)
    local splitted = split(file, ".")
    splitted[#splitted] = "c"
    return table.concat(splitted, ".")
end

local function concat(...) 
    local tables = {...}
    local result = {}
    for _, t in ipairs(tables) do 
        for _, element in ipairs(t) do 
            table.insert(result, element)
        end
    end
    return result
end

local function exists(path) 
    local file = io.open(path, "rb")
    local exists = file ~= nil
    local _unused = (exists and io.close(file))
    return exists
end

local function clean_up_objects(source_files)
    local files = 0
    source_files:for_each(function(file)
        files = files + ((os.remove("src/" .. objectify(file)) and 1) or 0)
        files = files + ((os.remove("src/" .. objectify(lto_prefix(file))) and 1) or 0)
        printf("Deleted %d object files\r", files)
    end)
    printf("\n")
end

local function clean_up_artifacts()
    os.remove("src/lua.exe")
    os.remove("src/luac.exe")
    os.remove("src/" .. lto_prefix("lua54.lib"))
    os.remove("src/lua54.lib")
    os.remove("src/lua54.dll")
    os.remove("src/lua54.def")
end

local function blank_if_not(cond, value) 
    return cond and value or ""
end

local function parse_makefile(file, key)
    file = io.open(file, "rb")
    if file == nil then printf("Error opening %s\n") os.exit(1) end
    local line_begin = true
    local result = array:new({})
    for line in file:lines() do
        if (starts(line, key)) or (not line_begin) then
            local list
            if line_begin then 
                list = split(line, "=")[2]
                list = array:new(split(list, "%s+"))
            else
                list = array:new(split(line, "%s+"))
            end
            if list[#list] == "\\" then
                list:pop()
                line_begin = false
            else
                line_begin = true
            end

            list:for_each(function(entry) result:push(entry) end)
        end
    end
    return result
end

return { printf = printf, move = move, run = run, starts = starts, split = split, objectify = objectify, sourceify = sourceify, concat = concat, lto_prefix = lto_prefix, exists = exists, clean_up_objects = clean_up_objects, clean_up_artifacts = clean_up_artifacts, blank_if_not = blank_if_not, parse_makefile = parse_makefile }