local utils = require("utils")
local array = require("array")

local source_files = array:new({})

-- Parsing makefile
for line in io.open("src/Makefile", "rb"):lines() do
    if utils.starts(line, "CORE_O") or utils.starts(line, "LIB_O") then
        local file_list = utils.split(line, "=")[2]
        file_list = utils.split(file_list, "%s+")
        for _, file in ipairs(file_list) do
            source_files:push(utils.sourceify(file))
        end
    end
end

utils.clean_up_objects(source_files)
utils.clean_up_artifacts()
print("Cleaned up")