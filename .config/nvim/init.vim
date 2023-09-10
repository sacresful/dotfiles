
call plug#begin()
Plug 'nvim-lualine/lualine.nvim'
call plug#end()

lua << END
require('lualine').setup()
END

set nocompatible
syntax on
set encoding=utf-8
set number relativenumber
filetype plugin on

:set mouse=a
set wildmode=longest,list,full
