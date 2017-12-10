## Purpose

To enable easy repl integration in vim. The inspiration for much of this is LightTables Instarepl and Emacs CIDER inline eval.

This plugin also offers "As you type" evalutation, like below.

![Imgur](http://i.imgur.com/8AgrdI3.gif)

This functionality can be switched off with the following config.

```viml
let g:aurepl_eval_on_type = 0
```

## Requirements

[vim-fireplace](https://github.com/tpope/vim-fireplace).

## Installation

Install using your favourite plugin manager,
I use [vim-plug](https://github.com/junegunn/vim-plug)

```viml
Plug 'markwoodhall/vim-aurepl'
```

## Configuration

When you send something to the repl the output of the command will appear inline, you can disable this with the following.

```viml
let g:aurepl_eval_inline = 0
```

## Commands

```viml
:LineToRepl
```

```viml
:FileToRepl
```

```viml
:SelectionToRepl
```

## License
Copyright © Mark Woodhall. Distributed under the same terms as Vim itself. See `:help license`
