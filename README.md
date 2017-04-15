## Purpose

To enable repl integration in vim.

## Installation

Install using your favourite plugin manager,
I use [vim-plug](https://github.com/junegunn/vim-plug)

```viml
Plug 'markwoodhall/vim-csrepl'
```

## Configuration

When you send a line to the repl the output of the command will appear inline, you can disable this with the following.

```viml
let g:csrepl_eval_inline = 0
```

## Commands

```viml
:LineToRepl
```

![line-to-repl](http://i.imgur.com/G2m7WKq.gif)

```viml
:FileToRepl
```

![file-to-repl](http://i.imgur.com/mDSiChI.gif)

```viml
:SelectionToRepl
```
![selection-to-repl](http://i.imgur.com/mDSiChI.gif)

## License
Copyright © Mark Woodhall. Distributed under the same terms as Vim itself. See `:help license`
