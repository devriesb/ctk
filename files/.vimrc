imap jk <esc>

let g:netrw_bufsettings = 'noma nomod nu nowrap ro nobl'
cabbrev E Explore

set tabstop=2
set shiftwidth=2
set expandtab

set number
set relativenumber
set ruler

set autoindent
set smartindent

syntax on


execute pathogen#infect()


" This is for vim-colors-solarized plugin
" Broken due to terminal colors or something
"syntax enable
"set background=dark
" let g:solarized_termcolors=256 " this fixes the terminal colors BUT AT WHAT
" COST
"colorscheme solarized
