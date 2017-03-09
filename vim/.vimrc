set nocompatible                   " required for vundle
filetype off                       " required for vundle
set rtp+=~/.vim/bundle/Vundle.vim  " required for vundle

call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'NLKNguyen/papercolor-theme'
Plugin 'altercation/vim-colors-solarized'

call vundle#end()

filetype plugin indent on
syntax enable

if has("win32") || has("win64")
 	let &undodir=$HOME . '\AppData\Local\VIM_UNDO_FILES\'
" else
" 	let &undodir=$HOME . '/.vim/VIM_UNDO_FILES/' . hostname()
endif

"set cpoptions=q
"set tabline=%M\ %t
set autoindent
set autoread
set backspace=indent,eol,start
set cindent
set cinoptions=(0,u0,g0,:0,j1,J1,)200
set colorcolumn=+1
set copyindent
"set cursorline
set encoding=utf8
set foldclose=all
set foldcolumn=1
set foldopen=all
set guioptions+=T
set guioptions+=m
set guioptions-=e
set guioptions-=r
set guioptions-=t
set guitablabel=%M\ %t
set history=1000
set hlsearch
set ignorecase
set incsearch
set laststatus=2
set linebreak
set listchars=eol:¬,extends:»,tab:▸\ ,trail:·
set matchpairs+=«:»
set matchtime=2
set noerrorbells
set noexpandtab
set nohidden
set nostartofline
set number
set numberwidth=1
set pastetoggle=<F8>
set ruler
set scrolloff=5
set shiftwidth=4
set shortmess=at
set showcmd
set showmatch
set showtabline=2
set smartcase
set smarttab
set softtabstop=0
set statusline=%{HasPaste()}%F%M%R%H%W%Y\ [%{&ff}]\ \ %<CWD:\ %r%{getcwd()}%h\ %=Line:\ %l\ \ \ Column:\ %v\ \ \ %p%%
set tabstop=4
set textwidth=80
set timeoutlen=1000
set ttymouse=urxvt
set undofile
set undolevels=5000
set visualbell t_vb=
set whichwrap+=<,>,[,],h,l
set wildmenu
set wildmode=longest,full
set wrap

" Make :help appear in a full-screen tab, instead of a window
augroup HelpInTabs
	autocmd!
	autocmd BufEnter  *.txt,*.txt.gz   call HelpInNewTab()
augroup END
function! HelpInNewTab ()
if &buftype == 'help'
	"Convert the help window to a tab...
	execute "normal \<C-W>T"
endif
endfunction

" Returns true if paste mode is enabled
function! HasPaste()
	if &paste
		return 'PASTE MODE  '
	endif
	return ''
endfunction

" Automatically have Regexes in 'Very Magical Mode'
nnoremap / /\v

" Make delete key in Normal mode remove the persistently highlighted matches
nmap <silent>  <BS>  :nohlsearch<CR>

" Mappings for dragvisuals
vmap  <expr>  <S-LEFT>   DVB_Drag('left')
vmap  <expr>  <S-RIGHT>  DVB_Drag('right')
vmap  <expr>  <S-DOWN>   DVB_Drag('down')
vmap  <expr>  <S-UP>     DVB_Drag('up')
vmap  <expr>  D          DVB_Duplicate()

" Colors & Fonts & Appearance
if has('gui_running')
	set columns=86
	set lines=34
endif
"let g:hybrid_custom_term_colors = 1
" color hybrid
set t_Co=256
set background=light
colorscheme PaperColor
call togglebg#map("<F5>")
set guifont=Consolas:h10

" Clang-Format & gofmt
if has("win32") || has("win64")
	map <C-K> :%pyfile C:\\Program Files\ (x86)\\LLVM\\share\\clang\\clang-format.py<cr>
	imap <C-K> <c-o>:%pyfile C:\\Program Files\ (x86)\\LLVM\\share\\clang\\clang-format.py<cr>
else
	map <C-K> :%pyfile /usr/share/clang/clang-format.py<cr>
	imap <C-K> <c-o>:%pyfile /usr/share/clang/clang-format.py<cr>
"	map <C-K> :%pyfile /usr/share/vim/addons/syntax/clang-format-3.6.py<cr>
"	imap <C-K> <c-o>:%pyfile /usr/share/vim/addons/syntax/clang-format-3.6.py<cr>
endif

autocmd FileType go map <C-K> :GoFmt<cr>
autocmd FileType go imap <C-K> <C-O>:GoFmt<cr>

" Comma as leader
let mapleader = ","
let g:mapleader = ","

" Useful mappings for managing tabs
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove
"map <M-PageDown> :tabnext<cr>
"map <M-PageUp> :tabprevious<cr>

" Treat long lines as break lines (useful when moving around in them)
map j gj
map k gk

" Map öö to the Esc functionality
inoremap öö <Esc>

" Always show filetypes in menu
if has('gui_running')
	let do_syntax_sel_menu = 1|runtime~! synmenu.vim|aunmenu &Syntax.&Show\ filetypes\ in\ menu
endif

" Show hightlighting groups for current word
nmap <C-S-P> :call <SID>SynStack()<CR>
function! <SID>SynStack()
	if !exists("*synstack")
		return
	endif
	echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endfunc

" Return to last edit position when opening files
autocmd BufReadPost *
			\ if line("'\"") > 0 && line("'\"") <= line("$") |
			\   exe "normal! g`\"" |
			\ endif

" Delete trailing whitespace on save
func! DeleteTrailingWS()
	exe "normal mz"
	%s/\s\+$//ge
	exe "normal `z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()
autocmd BufWrite *.coffee :call DeleteTrailingWS()
autocmd BufWrite *.hs :call DeleteTrailingWS()
autocmd BufWrite *.hamlet :call DeleteTrailingWS()
autocmd BufWrite *.julius :call DeleteTrailingWS()
autocmd BufWrite *.cassius :call DeleteTrailingWS()
autocmd BufWrite *.lucius :call DeleteTrailingWS()

" Modify GUI with ctrl+f1-2
if has("gui_running")
	nnoremap <C-F1> :if &go=~#'m'<Bar>set go-=m<Bar>else<Bar>set go+=m<Bar>endif<CR>
	nnoremap <C-F2> :if &go=~#'T'<Bar>set go-=T<Bar>else<Bar>set go+=T<Bar>endif<CR>
endif

" Update in insert mode
nmap <F2> :update<CR>
vmap <F2> <Esc><F2>gv
imap <F2> <c-o><F2>

" Toggle naughty characters
map <F6> :set list!<CR>
imap <F6> <c-o>:set list!<CR>

" Make it easy to navigate errors (and vimgreps)...
" nmap <silent> <RIGHT>         :cnext<CR>
" nmap <silent> <RIGHT><RIGHT>  :cnf<CR><C-G>
" nmap <silent> <LEFT>          :cprev<CR>
" nmap <silent> <LEFT><LEFT>    :cpf<CR><C-G>

