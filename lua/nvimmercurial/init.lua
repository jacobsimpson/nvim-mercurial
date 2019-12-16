local status = require("nvimmercurial/status")
local graphlog = require("nvimmercurial/graphlog")

status.register_close_callback(function()
    graphlog.close()
end)
graphlog.register_close_callback(function()
    status.close()
end)

local commit_msg_buf = -1;

-- Intentionally global. This function is used by the remote client callback to
-- determine if the commit edit buffer is still open or not.
function MercurialGetResult()
    return vim.api.nvim_buf_is_loaded(commit_msg_buf) and 1 or 0
end

-- Intentionally global. This function is used by the remote client callback to
-- start editing the commit message.
function MercurialEditCommitMessage(commit_message_filename, client_socket)
    vim.api.nvim_command(string.format(':sp %s', commit_message_filename))
    commit_msg_buf = vim.fn.bufnr(commit_message_filename)
end

return {
    status = status,
    graphlog = graphlog,
}
