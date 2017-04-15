## Purpose

To enable repl integration in vim.

## Requirements

At the moment this plugin requires the Mono C# repl, if at some point tbere is a better unerlying repl you can change the following.

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

When you send a line to the repl the output of the command will appear inline, you can disable this with the following.

```viml
let g:csrepl_eval_inline = 0
```

## Commands

```viml
:LineToRepl
```

![line-to-repl](http://i.imgur.com/Qm1M5Q5.gif)

```viml
:FileToRepl
```

![file-to-repl](http://i.imgur.com/JvqG44U.gif)

```viml
:SelectionToRepl
```
![selection-to-repl](http://i.imgur.com/8tg6VQ0.gif)

## License
Copyright © Mark Woodhall. Distributed under the same terms as Vim itself. See `:help license`
