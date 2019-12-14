local borderwin = require("nvime/borderwin")
local highlight = require("nvime/highlight")
local hglog = require("nvimmercurial/hglog")

local FILETYPE = 'hglog'

local hg_log_cmd = [[hg log -l 100 -G -T '{node|short} {author} {date|isodate}
{desc|fill68}
<<<<<<<<<<files>>>>>>>>>>
{files%"{status} {file}\n"}
<<<<<<<<<<copies>>>>>>>>>>
{file_copies%"{source}->{name}\n"}
<<<<<<<<<<done>>>>>>>>>>']]

local close_callback = nil
local mercurial_buf = -1
local mercurial_win = -1

local function get_log_buffer()
    if not vim.api.nvim_buf_is_loaded(mercurial_buf) then
        mercurial_buf, mercurial_win = borderwin.new()
        -- Open a split and switch to the buffer.
        --vim.api.nvim_command("split | b" .. mercurial_buf)
        vim.api.nvim_buf_set_option(mercurial_buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(mercurial_buf, 'filetype', FILETYPE)
        vim.api.nvim_buf_set_name(mercurial_buf, 'hg log')
    end
    return mercurial_buf, mercurial_win
end

-- This should be replaced by vim.gsplit or vim.split.
--local function split(inputstr, sep)
--    if sep == nil then
--        sep = "%s"
--    end
--    local t={}
--    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
--        table.insert(t, str)
--    end
--    return t
--end

-- This should be replaced by vim.trim().
--local function trim(s)
--   return (s:gsub("^%s*(.-)%s*$", "%1"))
--end

-- Sends a request to a remote Neovim instance for a commit message to be
-- entered, and waits for that buffer to be closed.
--local function RequestCommitMessage()
--    local channel = vim.fn.sockconnect('pipe',
--        '/var/folders/nh/lwpxl66111j103y85rw0kdvw0000gn/T/nvimNdff2D/0',
--        { rpc = true })
--    vim.fn.rpcrequest(
--        channel,
--        'nvim_command',
--        string.format(':e ~/.zshrc '
--            .. '| autocmd BufDelete <buffer> silent! call rpcnotify(%d, "BufDelete") '
--            ,, '| echo "this or that"', channel))
--end


--function! mercurial#SyncUpload()
--  echo "Syncing..."
--  let output = system('hg sync && hg uploadchain')
--  if v:shell_error != 0
--    redraw
--    echo output
--  else
--    redraw
--    echo "Synced!"
--  endif
--endfunction
--
--function! mercurial#Amend()
--  echo "Amending..."
--  let output = system('hg amend')
--  if v:shell_error != 0
--    redraw
--    echo output
--  else
--    redraw
--    echo "Amended!"
--  endif
--endfunction
--
--function! mercurial#Resolve()
--  let f = expand('%')
--  let output = system('hg resolve --mark ' . f)
--  if v:shell_error != 0
--    echo output
--  else
--    echo "Resolved!"
--  endif
--endfunction
--

local function start(processLine)
    -- hg help templates for more information about how to format log output.
    -- Currently, jobstart only functions with VimL code.
    -- https://github.com/neovim/neovim/issues/7607
    local handle = io.popen(hg_log_cmd)
    --local result = handle:read("*a")
    for line in handle:lines() do
        processLine(line)
    end
    handle:close()
end

local function refresh_graph_log(buf, win)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    local parse = hglog.Parser()

    local beginning = 0
    local first = 0
    local line_count = 0
    -- I would much prefer to use `jobstart` here, rather than my own
    -- implementation backed by the Lua `system` call, but `jobstart` is not
    -- yet supported in Lua.
    start(function(line)
        local commit = parse(line)
        -- Parse will only return a result when a full commit is available to
        -- be appended to the buffer.
        if commit ~= nil then
            -- Append the text.
            local lines = commit:Lines()
            local indent = string.len(commit:getIndentation())
            vim.api.nvim_buf_set_lines(buf, beginning, -1, false, lines)
            -- Adjust the cursor position to the location of the current commit.
            if commit:isWorking() then
                vim.api.nvim_win_set_cursor(win, {line_count + 1, indent - 3})
            end
            line_count = line_count + #lines

            -- Add some syntax highlighting.
            vim.api.nvim_buf_add_highlight(buf, -1, "Constant", first, indent, indent+12)
            local loc = string.find(lines[1], ">")
            vim.api.nvim_buf_add_highlight(buf, -1, "Statement", first, indent+13, loc)

            -- Add folds.
            local foldRange = commit:GetFileFold()
            vim.api.nvim_command("" .. (first + foldRange[1]) .. "," .. (first + foldRange[2]) .. "fo")
            foldRange = commit:GetDescriptionFold()
            vim.api.nvim_command("" .. (first + foldRange[1]) .. "," .. (first + foldRange[2]) .. "fo")

            -- The first time through, set the range to replace as the whole
            -- buffer, so that there won't be an empty line at the top.
            -- Subsequent additions to the buffer will be appending.
            beginning = -1
            first = first + commit:GetLength()
        end
    end)

    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function open()
    print("Loading ...")
    if close_callback ~= nil then
        close_callback()
    end
    local buf, win = get_log_buffer()
    vim.api.nvim_buf_set_option(buf, 'filetype', FILETYPE)
    vim.api.nvim_win_set_option(win, 'foldtext', 'MercurialFoldText()')
    vim.api.nvim_win_set_option(win, 'fillchars', 'fold: ')
    vim.api.nvim_win_set_option(win, 'foldcolumn', 0)

    -- The existing Fold highlight should be preserved and restored when
    -- the buffer closes.
    local folded = vim.fn.substitute(vim.trim(vim.fn.execute("highlight Folded")), " xxx ", "", "")
    vim.api.nvim_command('autocmd BufLeave <buffer> highlight ' .. folded)

    -- Make the Folded highlight the same as the Normal highlight so that a
    -- Mercurial log will look normal and readable, less distraction, but
    -- additional detail is available on request.
    local normal = highlight.get_highlight("Normal")
    highlight.set_highlight("Folded", normal)

    refresh_graph_log(buf, win)

    -- Set the buffer so the text doesn't wrap to the next line if it is longer
    -- than the width of the buffer.
    vim.api.nvim_win_set_option(win, 'wrap', false)
    -- Set the buffer so that searches don't wrap off the bottom of the buffer
    -- around to the top again.
    vim.api.nvim_set_option("wrapscan", false)
    vim.api.nvim_command("redraw")
    print(" ")
end

local function update()
    print("Updating...")
    local currentLine = vim.fn.getline(".")
    local commit = vim.fn.matchstr(currentLine, '^[:| ]*[o@_x*+][:| ]*  [0-9a-f]* ')
    if vim.fn.empty(commit) ~= 0 then
        print("Not a valid commit line. Can not update.")
        return
    end
    commit = vim.fn.matchstr(commit, string.rep('[0-9a-f]', 12))
    local output = vim.fn.system('hg update ' .. commit)
    if vim.api.nvim_get_vvar("shell_error") ~= 0 then
      vim.api.nvim_command("redraw")
      print(output)
    else
      vim.api.nvim_command("redraw")
    end
    refresh_graph_log()
end

local function fold_close()
    if vim.fn.foldlevel(vim.fn.line('.')) == 0 then
        vim.fn.execute("normal! zjzck")
    else
        vim.fn.execute("normal! zc")
    end
end

local function fold_open()
    if vim.fn.foldlevel(vim.fn.line('.')) == 0 then
        vim.fn.execute("normal! zjzozj")
    else
        vim.fn.execute("normal! zo")
    end
end

local function move_forward()
    vim.fn.search("[o@_x*+][ |]*  [0-9a-f]* ", "W")
end

local function move_backward()
    vim.fn.search("[o@_x*+][ |]*  [0-9a-f]* ", "bW")
end

local function set_log_command(cmd)
    hg_log_cmd = cmd
end

local function close()
    if vim.api.nvim_buf_is_loaded(mercurial_buf) then
        vim.fn.execute("bdelete! " .. mercurial_buf)
    end
    if vim.api.nvim_win_is_valid(mercurial_win) then
        vim.api.nvim_win_close(mercurial_win, true)
    end
end

local function register_close_callback(cb)
    close_callback = cb
end

return {
    FILETYPE = FILETYPE,

    close = close,
    fold_close = fold_close,
    fold_open = fold_open,
    open = open,
    move_backward = move_backward,
    move_forward = move_forward,
    set_log_command = set_log_command,
    register_close_callback = register_close_callback,
    update = update,
}
