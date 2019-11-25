local borderwin = require("nvime/borderwin")
local hglog = require("nvimmercurial/hglog")
local highlight = require("nvime/highlight")

-- nvim_subscribe might help me receive an rpcnotify.

local HG_STATUS_FILETYPE = 'hgstatus'
local HG_GRAPHLOG_FILETYPE = 'hgxl'

local files = {}
local statusBuffer = -1

local function Commit()
    -- Commit selected files, or if there are no files selected, commit all changes.
    -- HGEDITOR=<something to invoke this instance of Neovim.> hg commit
    -- Close the existing status window.
end

-- If the current buffer is a status buffer, check which file currently has the
-- cursor bside it, and return that. This way, the cursor can be restored to
-- the same file after the status has been updated. Sometimes a status update
-- can cause files to be reordered.
local function store_active_file()
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_option(buf, 'filetype') ~= HG_STATUS_FILETYPE then
        return nil
    end
    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    local row = cursor[1]
    if files[row] == nil then
        return nil
    end
    return files[row]['filename']
end

local function load_status()
    local new_files = {}
    local indexed = {}
    local handle = io.popen("hg status")
    local result = handle:read("*a")
    handle:close()

    for _, v in ipairs(vim.split(result, "\n")) do
        if string.len(vim.trim(result)) > 0 then
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
    for _, f in ipairs(files) do
        local i = indexed[f['filename']]
        if i ~= nil then
            i['selected'] = f['selected']
        end
    end

    files = new_files
end

local function get_status_buffer()
    if not vim.api.nvim_buf_is_loaded(statusBuffer) then
        statusBuffer = borderwin.New()
        -- Open a split and switch to the buffer.
        --vim.api.nvim_command("split | b" .. statusBuffer)
        vim.api.nvim_buf_set_option(statusBuffer, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(statusBuffer, 'filetype', HG_STATUS_FILETYPE)
        vim.api.nvim_buf_set_name(statusBuffer, 'hg status')
    end
    return statusBuffer
end

local function show_status()
    local lines = {}
    for _, f in ipairs(files) do
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

-- If a file is passed in, look for that file in the current status buffer, and
-- put the cursor bside it. If there is no active file passed in, or the active
-- file is no longer in the status output, the cursor will end up on the first
-- file.
local function restore_active_file(active)
    local cursor = {1, 2}
    if active ~= nil then
        for i, f in ipairs(files) do
            if f['filename'] == active then
                cursor[1] = i
                break
            end
        end
    end
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), cursor)
end

local function AddFile()
    -- As far as I can tell, the neovim job control functions are not yet
    -- natively available from Lua, so usin the native Lua version for the
    -- moment. The native Lua version does not have an option to read stdout
    -- and stderr.
    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    local handle = io.popen("hg add " .. files[cursor[1]]['filename'])
    handle:read("*a")
    handle:close()

    local active = store_active_file()
    load_status()
    show_status()
    restore_active_file(active)
end

local function RevertFile()
    -- As far as I can tell, the neovim job control functions are not yet
    -- natively available from Lua, so usin the native Lua version for the
    -- moment. The native Lua version does not have an option to read stdout
    -- and stderr.
    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    local handle = io.popen("hg revert " .. files[cursor[1]]['filename'])
    handle:read("*a")
    handle:close()

    local active = store_active_file()
    load_status()
    show_status()
    restore_active_file(active)
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

local function ToggleFileSelect()
    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    files[cursor[1]]['selected'] = not files[cursor[1]]['selected']
    show_status()
end

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
    local handle = io.popen([[hg log -l 100 -G -T '{node|short} {author} {date|isodate}
{desc|fill68}
<<<<<<<<<<files>>>>>>>>>>
{files%"{status} {file}\n"}
<<<<<<<<<<copies>>>>>>>>>>
{file_copies%"{source}->{name}\n"}
<<<<<<<<<<done>>>>>>>>>>']])
    --local result = handle:read("*a")
    for line in handle:lines() do
        processLine(line)
    end
    handle:close()
end

local function Update()
  print("Updating...")
  local currentLine = vim.fn.getline(".")
  local commit = vim.fn.matchstr(currentLine, '^[:| ]*[@*ox]  [0-9a-f]* ')
  if vim.fn.empty(commit) ~= 0 then
--    throw "Not a valid commit line. Can not update."
      print("Not a valid commit line. Can not update.")
      return
  end
  commit = vim.fn.matchstr(commit, string.rep('[0-9a-f]', 12))
  print ("commit = " .. commit)
  local output = vim.fn.system('hg update ' .. commit)
  if vim.api.nvim_get_vvar("shell_error") ~= 0 then
    vim.api.nvim_command("redraw")
    print(output)
  else
    vim.api.nvim_command("redraw")
    print("Updated!")
    vim.api.nvim_command(':bd')
  end
end

local function GraphLog()
    print("Loading ...")
    local buf, win = borderwin.New()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_option(buf, 'filetype', HG_GRAPHLOG_FILETYPE)
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
    local normal = highlight.getHighlight("Normal")
    highlight.setHighlight("Folded", normal)

    local parse = hglog.Parser()

    -- I would much prefer to use `jobstart` here, rather than my own
    -- implementation backed by the Lua `system` call, but `jobstart` is not
    -- yet supported in Lua.
    local beginning = 0
    local first = 0
    start(function(line)
        local commit = parse(line)
        -- Parse will only return a result when a full commit is available to
        -- be appended to the buffer.
        if commit ~= nil then
            vim.api.nvim_buf_set_lines(buf, beginning, -1, false, commit:Lines())
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
    -- Set the buffer so the text doesn't wrap to the next line if it is longer
    -- than the width of the buffer.
    vim.api.nvim_win_set_option(win, 'wrap', false)
    -- Set the buffer so that searches don't wrap off the bottom of the buffer
    -- around to the top again.
    --vim.api.nvim_command("set nowrapscan")
    vim.api.nvim_set_option("wrapscan", false)
    vim.api.nvim_win_set_cursor(win, {1, 1})
    vim.api.nvim_command("redraw")
    print(" ")
    --exe '/\v[@]  [0-9a-f]* jacobsimpson.*|[@]  [0-9a-f]* .*p4head'
end

local function Status()
    local active = store_active_file()
    load_status()
    show_status()
    restore_active_file(active)
end

local function MoveForward()
    vim.fn.search("[@ox]  [0-9a-f]* ", "W")
end

local function MoveBackward()
    vim.fn.search("[@ox]  [0-9a-f]* ", "bW")
end

nvimmercurial = {
    HG_STATUS_FILETYPE = HG_STATUS_FILETYPE,
    HG_GRAPHLOG_FILETYPE = HG_GRAPHLOG_FILETYPE,

    AddFile = AddFile,
    Commit = Commit,
    GraphLog = GraphLog,
    RevertFile = RevertFile,
    Status = Status,
    ToggleFileSelect = ToggleFileSelect,
    Update = Update,
    MoveBackward = MoveBackward,
    MoveForward = MoveForward,
}
