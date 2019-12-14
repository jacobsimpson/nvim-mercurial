local status = require("nvimmercurial/status")
local graphlog = require("nvimmercurial/graphlog")

-- nvim_subscribe might help me receive an rpcnotify.

status.register_close_callback(function()
    graphlog.close()
end)
graphlog.register_close_callback(function()
    status.close()
end)


return {
    status = status,
    graphlog = graphlog,
}
