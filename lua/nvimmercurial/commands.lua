
local function move(dst)
    local src = vim.fn.expand("%")
    local output = vim.fn.system(string.format('hg move "%s" "%s"', src, dst))
    if vim.api.nvim_get_vvar("shell_error") ~= 0 then
        print(output)
    else
        vim.api.nvim_buf_set_name(0, dst)
        vim.fn.execute("w!")
    end
end

return {
    move = move,
}
