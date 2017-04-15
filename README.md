## Purpose

To enable repl integration in vim.

## Requirements

At the moment this plugin requires the Mono C# repl, if at some point there is a better underlying repl available you can change the following.

```viml
let g:csrepl_use_command = 'somenewrepl'
```

## Installation

Install using your favourite plugin manager,
I use [vim-plug](https://github.com/junegunn/vim-plug)

```viml
Plug 'markwoodhall/vim-csrepl'
```

## Configuration

When you send a something to the repl the output of the command will appear inline, you can disable this with the following.

```viml
let g:csrepl_eval_inline = 0
```

## Commands

```viml
:LineToRepl
```

![line-to-repl](http://i.imgur.com/1OQb1Dt.gif)

```viml
:FileToRepl
```

![file-to-repl](http://i.imgur.com/nb0aNJC.gif)

```viml
:SelectionToRepl
```
![selection-to-repl](http://i.imgur.com/fD73U3g.gif)

## License
Copyright © Mark Woodhall. Distributed under the same terms as Vim itself. See `:help license`
