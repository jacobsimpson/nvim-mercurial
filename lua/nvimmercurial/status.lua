local borderwin = require("nvime/borderwin")

local FILETYPE = 'hgstatus'

local status_details = {}
local mercurial_buf = -1
local mercurial_win = -1

local function commit()
    -- Commit selected files, or if there are no files selected, commit all changes.
    -- HGEDITOR=<something to invoke this instance of Neovim.> hg commit
    -- Close the existing status window.
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

local function go_status_file()
    local file = get_active_file()
    vim.fn.execute("e " .. file)
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

local function show_status()
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

local function toggle_file_select()
    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    status_details[cursor[1]]['selected'] = not status_details[cursor[1]]['selected']
    show_status()
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

local function open()
    local active = get_active_file()
    load_status()
    show_status()
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
    show_status()
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
    show_status()
    restore_active_file(active)
end

local function close()
    if vim.api.nvim_buf_is_loaded(mercurial_buf) then
        vim.fn.execute("bdelete! " .. mercurial_buf)
    end
    if vim.api.nvim_win_is_valid(mercurial_win) then
        vim.api.nvim_win_close(mercurial_win, true)
    end
end

return {
    FILETYPE = FILETYPE,

    add_file = add_file,
    close = close,
    commit = commit,
    go_status_file = go_status_file,
    open = open,
    revert_file = revert_file,
    show_status = show_status,
    toggle_file_select = toggle_file_select,
}
