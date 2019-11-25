std = {
     globals = {}, -- these globals can be set and accessed.

     -- These are globals that Neovim makes available by default which should
     -- be treated as read only.
     read_globals = {
         "vim",
         "math",
         "io",
         "print",
         "string",
         "ipairs",
         "table",
         "require",
         "setmetatable",
     }
}

files["lua/nvimmercurial/init.lua"] = {
    new_globals = {
        "nvimmercurial",
    }
}

