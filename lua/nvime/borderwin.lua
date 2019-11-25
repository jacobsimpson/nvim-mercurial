function New()
  -- get the editor's max width and height
  local editor_width = vim.api.nvim_get_option("columns")
  local editor_height = vim.api.nvim_get_option("lines")

  -- Popup window will be 3/4 of the editor_height, but not more than 30
  local win_height
  local win_width

  -- if the editor_height is too small
  if editor_height < 10 then
      win_height = editor_height - 2
  else
      win_height = math.min(math.ceil(editor_height * 3 / 4), 30)
  end

  -- if the editor_width is small
  if editor_width < 150 then
    -- just subtract 8 from the editor's editor_width
    win_width = math.ceil(editor_width - 8)
  else
    -- use 90% of the editor's editor_width
    win_width = math.ceil(editor_width * 0.9)
  end

  -- settings for the border window
  local opts = {
    relative = "editor",
    -- Disable various visual features that might be inherited from the current
    -- window.
    style = "minimal",
    width = win_width,
    height = win_height,
    row = math.ceil((editor_height - win_height) / 2),
    col = math.ceil((editor_width - win_width) / 2)
  }

  -- Put the frame around the edges of the frame buffer.
  local lines = {
    "╭" .. string.rep("─", win_width - 2) .. "╮"
  }
  for i = 2, win_height-1 do
    lines[i] = "│" .. string.rep(" ", win_width - 2) .. "│"
  end
  lines[win_height] = "╰" .. string.rep("─", win_width - 2) .. "╯"

  -- create a new buffer to contain the frame that will surround the inner,
  -- content frame.
  local frame_buf = vim.api.nvim_create_buf(false, true)

  -- create a new floating window, centered in the editor
  local frame_win = vim.api.nvim_open_win(frame_buf, true, opts)
  vim.api.nvim_buf_set_option(frame_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_lines(frame_buf, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(frame_buf, 'modifiable', false)
  vim.api.nvim_win_set_option(frame_win, 'winhighlight', 'Normal:Normal')

  -- Adjust the content frame in by 1 on each edge, so when content is put in
  -- the content buffer, it will be within the frame displayed around the edge
  -- of the frame buffer.
  opts.row = opts.row + 1
  opts.height = opts.height - 2
  opts.col = opts.col + 2
  opts.width = opts.width - 4

  local content_buf = vim.api.nvim_create_buf(false, true)
  local content_win = vim.api.nvim_open_win(content_buf, true, opts)
  vim.api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')

  -- Now that the two frames exist, tie them together so that closing one
  -- closes the other.
  -- I know of a couple ways to close or navigate away and these seem to cover
  -- them. :bd, :bw, :bn, :h <topic>
  vim.api.nvim_command('autocmd BufLeave <buffer> bw! ' .. frame_buf)
  vim.api.nvim_command('autocmd BufLeave <buffer> bw! ' .. content_buf)

  return content_buf, content_win
end

return {
    New = New
}
