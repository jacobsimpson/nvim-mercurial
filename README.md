# nvim-mercurial

WARNING - This plugin only works in Neovim 0.5.0. I'll add a version check to
the plugin.

## Introduction

A Neovim plugin that integrates with Mercurial. Heavily inspired by
[vim-fugitive](https://github.com/tpope/vim-fugitive).

## Installation

Configure the plugin through your plugin manager. For vim-plug, add this line:

```vim
Plug 'jacobsimpson/nvim-mercurial'
```

## Development

```sh
nvim --cmd "set rtp+=./nvim-mercurial"
```

```sh
luarocks install luacheck
luacheck --config luachceck.lua lua
```
