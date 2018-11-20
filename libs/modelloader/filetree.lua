--把shaderc.lua的树形文件结构抽离出来使用

dofile "libs/init.lua"

require "iupluaimglib"
require "scintilla"

iup.SetGlobal("UTF8MODE", "YES")
iup.SetGlobal("UTF8MODE_FILE", "YES")

local fs = require "lfs"
local toolset = require "editor.toolset"
local path = toolset.load_config()
local seri = require "serialize.util"

local function filetree(filter, message)
    local dir_view = iup.tree {
        HIDEBUTTONS = "yes",
        HIDELINES = "yes",
    }
    local file_view = iup.list {
        expand = "yes",
    }

    local current_path = nil
    local current_info = {}

    local function load_path()
        local config_name = toolset.homedir .. "/shaderc.lua"
        local config = seri.load(config_name) or {}
        if not config.drive then
            return
        end
        local info = current_info[config.drive]
        if not info then
            return
        end
        current_path = info
        if config.path then
            for k,v in ipairs(config.path) do
                info.path[k] = v
            end
        end
    end

    local function save_path()
        local config_name = toolset.homedir .. "/shaderc.lua"
        seri.save(config_name, {
            drive = current_path.drive,
            path = current_path.path,
        })
    end

    local function switch_drive(name)
        current_path = assert(current_info[name])
    end

    local function reflush_filelist(filelist)
        file_view[1] = nil
        local pat = "%." .. filter .. "$"
        local index = 1
        while filelist[index] do
            if not filelist[index]:match(pat) then
                local n = #filelist
                filelist[index] = filelist[n]
                filelist[n] = nil
            else
                index = index + 1
            end
        end

        if next(filelist) == nil then
            return
        end

        table.sort(filelist)
        for k, v in ipairs(filelist) do
            file_view[k] = v
        end

        function file_view:dblclick_cb(id, name)
            local f = message.choosefile
            if f then
                f(current_path.drive .. table.concat(current_path.path, "/") .. "/" .. name)
            end
        end
    end

    --- directory tree

    local function is_dir(pathname)
        return fs.attributes(pathname, "mode") == "directory"
    end

    local function rebuild_tree(drive)
        switch_drive(drive)
        dir_view.delnode0 = "CHILDREN"
        dir_view.title0 = current_path.drive_name
        local index = 0
        local pathname = current_path.drive
        for _,v in ipairs(current_path.path) do
            if is_dir(pathname..v) then
                dir_view["addbranch"..index] = v
                index = index + 1
                pathname = pathname .. v .. "/"
            else
                break
            end
        end
        dir_view.value = index
        local subdir = {}
        local filelist = {}
        -- todo: capture dir error
        for name in fs.dir(pathname) do
            if name ~= "." and name ~= ".." then
                if is_dir(pathname .. name) then
                    table.insert(subdir, name)
                else
                    table.insert(filelist, name)
                end
            end
        end
        if next(subdir) then
            table.sort(subdir)
            local addbranch = "addleaf" .. index
            local image = "image" .. (index + 1)
            for i = #subdir, 1, -1 do
                dir_view[addbranch] = subdir[i]
                dir_view[image] = "IMGCOLLAPSED"
            end
        end

        reflush_filelist(filelist)

        save_path()

        function dir_view:executeleaf_cb(id)
            local subindex = id - index
            table.insert(current_path.path, subdir[subindex])
            rebuild_tree(drive)
        end

        function dir_view:branchclose_cb(id)
            for i = id + 1, #current_path.path do
                current_path.path[i] = nil
            end
            rebuild_tree(drive)
            return iup.IGNORE
        end
    end

    --- drive list
    local function drives()
        local d = fs.drives()
        local ret = {}
        for k,v in ipairs(d) do
            local item = { drive = v, name = v }
            local name = d[v]
            if name then
                item.name = v .. " " .. name
            end
            current_info[v] = {
                drive = v,
                drive_name = item.name,
                path = {},
            }
            table.insert(ret, item)
        end
        return ret
    end

    local function drive_list(d)
        local init = {}
        local current = 1
        for k,v in ipairs(d) do
            init[k] = v.name
            if current_path and v.name == current_path.drive then
                current = k
            end
        end
        init.value = current
        init.dropdown = "YES"
        init.visible_items = #init + 1
        init.expand = "HORIZONTAL"
        local ctrl = iup.list(init)
        switch_drive(d[current].drive)
        -- todo: action

        function ctrl:action(name, index, state)
            if state == 1 then
                rebuild_tree(d[index].drive)
            end
        end

        return ctrl
    end

    local dlist = drives()
    load_path()
    return {
        view = iup.vbox {
            drive_list(dlist),
            iup.split {
                dir_view,
                file_view,
                ORIENTATION = "HORIZONTAL",
                SHOWGRIP = "NO",
                value = "500",
            },
        },
        rebuild = function()
            rebuild_tree(current_path.drive)
        end
    }
end

--shaderc文档查看的组件，暂时不需要，也不去更改了
---[[
----------- fileview & output ------
local function filebuilder()
    local source = iup.scintilla {
        MARGINWIDTH0 = "30",	-- line number
        STYLEFONT33 = "Consolas",
        STYLEFONTSIZE33 = "11",
        STYLEVISIBLE33 = "NO",
        expand = "YES",
        WORDWRAP = "CHAR",
        APPENDNEWLINE = "NO",
        READONLY = "YES",
        LEXERLANGUAGE = "cpp",
        STYLEFGCOLOR1 = "192 192 192", -- 1-C comment
        STYLEFGCOLOR2 = "192 192 192", -- 2-C++ comment line
        STYLEFGCOLOR4 = "0 192 0", -- 4-Number
        STYLEFGCOLOR5 = "0 0 128", -- 5-Keyword
        STYLEFGCOLOR6 = "160 20 20", -- 6-String
        STYLEFGCOLOR7 = "64 0 0", -- 7-Character
        STYLEFGCOLOR9 = "0 0 255", -- 9-Preprocessor block
        STYLEFGCOLOR10 = "128 0 128", -- 10-Operator
        KEYWORDS0 = "void $input $output vec4 mul",
    }
    local filename = iup.label { expand =  "HORIZONTAL" }
    local compile = iup.button { title = "Compile" }
    local output = iup.text {
        multiline = "yes",
        wordwrap = "yes",
        readonly = "yes",
        expand = "yes",
    }

    function compile.action()
        local fn = filename.title
        if fn then
            local dest = fn:gsub("(%w+).sc", "%1") .. ".bin"
            local tbl = {
                shaderc = path.shaderc,
                src = fn,
                dest = dest,
                inc = "",
                stype = nil,
                smodel = nil
            }
            if path.shaderinc then
                tbl.inc = '-i "' .. path.shaderinc .. '"'
            end
            local vf = fn:match "[/\\]([fv])s_[^/\\]+.sc$"
            if vf == "f" then
                tbl.smodel = "ps_4_0"
                tbl.stype = "fragment"
            elseif vf == "v" then
                tbl.smodel = "vs_4_0"
                tbl.stype = "vertex"
            else
                output.append = "shader name should be fs_*.sc or vs_*.sc"
                return
            end

            local command = string.gsub('$shaderc --platform windows --type $stype -p $smodel -O 3 -f "$src" -o "$dest" $inc',
                    "%$(%w+)", tbl)

            output.append = command

            local prog, err = io.popen(command .. "  2>&1")

            if not prog then
                output.append = err
            else
                local ret = prog:read "a"
                prog:close()
                output.append = ret
            end
        end
    end

    local ctrl = iup.vbox {
        source,
        iup.hbox {
            filename,
            compile,
        },
        output,
    }
    local function update_file(name)
        source.readonly = "NO"
        local f = assert(io.open(name, "rb"))
        source.value = f:read "a"
        f:close()
        filename.title = name
        source.readonly = "yes"
    end
    return {
        view = ctrl,
        update = update_file,
    }
end
--]]
------------------------------------

local message = {}

local tree_template = {}
tree_template.tree = filetree("sc", message)
tree_template.file = filebuilder()
tree_template.tree.rebuild()

function message.choosefile(name)
    file.update(name)
end

return tree_template