local borderwin = require("nvime/borderwin")

-- This path appears to come from the Vim runtimepath (rtp). It might be
-- relative. However, I believe, that in order for this file to actually
-- successfully load, and this code to execute, then the relative path is
-- relative to Vim's current working directory.
package_path = debug.getinfo(1, 'S').source
if string.sub(package_path, 1, 1) == '@' then
    package_path = string.sub(package_path, 2)
end
if string.sub(package_path, 1, 1) == '.' then
    package_path = vim.fn.getcwd() .. '/' .. package_path
end

package_path = vim.fn.simplify(package_path)
package_path = string.sub(package_path, 0, vim.fn.strridx(package_path, "/"))
package_path = string.sub(package_path, 0, vim.fn.strridx(package_path, "/"))
package_path = string.sub(package_path, 0, vim.fn.strridx(package_path, "/"))

local FILETYPE = 'hgstatus'

local close_callback = nil
local status_details = {}
local mercurial_buf = -1
local mercurial_win = -1

function join(list, delimiter)
  local len = #list
  if len == 0 then
    return ""
  end
  local s = list[1]
  for i = 2, len do
    s = s .. delimiter .. list[i]
  end
  return s
end

local function get_selected_files()
    local selected_files = {}
    for _, f in ipairs(status_details) do
        if f['selected'] then
            table.insert(selected_files, f['filename'])
        end
    end
    return selected_files
end

local function load_status()
    local new_files = {}
    local indexed = {}
    local handle = io.popen("hg status")
    local result = handle:read("*a")
    handle:close()

    for _, v in ipairs(vim.split(result, "\n")) do
        if string.len(vim.trim(v)) > 0 then
            local f = {
              selected = false,
              status = string.sub(v, 1, 1),
              filename = string.sub(v, 3),
            }
            table.insert(new_files, f)
            indexed[f['filename']] = f
        end
    end

    -- Transfer the selected status from the previous list of files.
    for _, f in ipairs(status_details) do
        local i = indexed[f['filename']]
        if i ~= nil then
            i['selected'] = f['selected']
        end
    end

    status_details = new_files
end

local function get_status_buffer()
    if not vim.api.nvim_buf_is_loaded(mercurial_buf) then
        mercurial_buf, mercurial_win = borderwin.new()
        -- Open a split and switch to the buffer.
        --vim.api.nvim_command("split | b" .. mercurial_buf)
        vim.api.nvim_buf_set_option(mercurial_buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(mercurial_buf, 'filetype', FILETYPE)
        vim.api.nvim_buf_set_name(mercurial_buf, 'hg status')
    end
    return mercurial_buf, mercurial_win
end

local function refresh()
    local lines = {}
    for _, f in ipairs(status_details) do
        table.insert(lines, string.format(" [%s] %s %s",
            f['selected'] and 'X' or ' ',
            f['status'],
            f['filename']))
    end

    local buf = get_status_buffer()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function close()
    if vim.api.nvim_buf_is_loaded(mercurial_buf) then
        vim.fn.execute("bdelete! " .. mercurial_buf)
    end
    if vim.api.nvim_win_is_valid(mercurial_win) then
        vim.api.nvim_win_close(mercurial_win, true)
    end
end

local function commit()
    -- Commit selected files, or if there are no files selected, commit all changes.
    -- HGEDITOR=<something to invoke this instance of Neovim.> hg commit
    -- Close the existing status window.
    local selected_files = get_selected_files()
    local files = table.concat(selected_files, " ")

    -- Set the HGEDITOR environment variable so that when `hg commit` starts,
    -- it will use this command as the editor. This command uses nvim as an
    -- interpreter for a small chunk of Vimscript that makes a remote call back
    -- to this instance of nvim.
    local client_script = package_path .. "/" .. "client.vim"
    vim.api.nvim_exec("let $HGEDITOR='nvim --noplugin -R -n --headless -u " .. client_script .. "'" , true)
    -- Set NVIM_SERVER so when the next instance of nvim is started by `hg
    -- commit`, it will know the address of this current instance and be able
    -- to call back.
    vim.api.nvim_exec("let $NVIM_SERVERNAME='" .. vim.api.nvim_get_vvar("servername") .. "'", true)
    -- At this point, nvim calls out to hg commit, which will run another nvim
    -- instance, which will call back to this running instance. This instance
    -- can't be blocked waiting for vim.fn.system(...), or any other blocking
    -- shell function, to complete. `jobstart` will run `hg commit` async. That
    -- means this instance will be available to accept the call back from `hg
    -- commit` trying to start the editor.
    local status = vim.fn.jobstart('hg commit ' .. files)
    if status == 0 then
        -- There was an error when attempting to start the external command.
        print("Failed to commit changes.")
    else
        -- Clear the commit screen.
        close()
    end
end

-- If a file is passed in, look for that file in the current status buffer, and
-- put the cursor beside it. If there is no active file passed in, or the
-- active file is no longer in the status output, the cursor will end up on the
-- first file.
local function restore_active_file(active)
    local cursor = {1, 2}
    if active ~= nil then
        for i, f in ipairs(status_details) do
            if f['filename'] == active then
                cursor[1] = i
                break
            end
        end
    end
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), cursor)
end

-- If the current buffer is a status buffer, check which file currently has the
-- cursor beside it, and return that. This way, the cursor can be restored to
-- the same file after the status has been updated. Sometimes a status update
-- can cause files to be reordered.
local function get_active_file()
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_option(buf, 'filetype') ~= FILETYPE then
        return nil
    end
    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    local row = cursor[1]
    if status_details[row] == nil then
        return nil
    end
    return status_details[row]['filename']
end

local function go_file()
    local file = get_active_file()
    vim.fn.execute("e " .. file)
end

local function toggle_file_select()
    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    status_details[cursor[1]]['selected'] = not status_details[cursor[1]]['selected']
    refresh()
end

local function open()
    if close_callback ~= nil then
        close_callback()
    end
    local active = get_active_file()
    load_status()
    refresh()
    restore_active_file(active)
end

local function revert_file()
    -- As far as I can tell, the neovim job control functions are not yet
    -- natively available from Lua, so usin the native Lua version for the
    -- moment. The native Lua version does not have an option to read stdout
    -- and stderr.
    local file = get_active_file()
    local handle = io.popen("hg revert " .. file)
    handle:read("*a")
    handle:close()

    local active = get_active_file()
    load_status()
    refresh()
    restore_active_file(active)
end

local function add_file()
    -- As far as I can tell, the neovim job control functions are not yet
    -- natively available from Lua, so using the native Lua version for the
    -- moment. The native Lua version does not have an option to read stdout
    -- and stderr.
    local file = get_active_file()
    local handle = io.popen("hg add " .. file)
    handle:read("*a")
    handle:close()

    local active = get_active_file()
    load_status()
    refresh()
    restore_active_file(active)
end

local function register_close_callback(cb)
    close_callback = cb
end

local function shelve()
    local selected_files = get_selected_files()
    local files = table.concat(selected_files, " ")
    local output = vim.fn.system('hg shelve ' .. files)
    if vim.api.nvim_get_vvar("shell_error") ~= 0 then
        vim.api.nvim_command("redraw")
        print(output)
    else
        vim.api.nvim_command("redraw")
        load_status()
        refresh()
    end
end

local function unshelve()
  local output = vim.fn.system('hg unshelve')
  if vim.api.nvim_get_vvar("shell_error") ~= 0 then
    vim.api.nvim_command("redraw")
    print(output)
  else
    vim.api.nvim_command("redraw")
    load_status()
    refresh()
  end
end

return {
    FILETYPE = FILETYPE,

    add_file = add_file,
    close = close,
    commit = commit,
    go_file = go_file,
    open = open,
    register_close_callback = register_close_callback,
    revert_file = revert_file,
    refresh = refresh,
    toggle_file_select = toggle_file_select,
    shelve = shelve,
    unshelve = unshelve,
}
