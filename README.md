## Purpose

To enable easy repl integration in vim. The inspiration for much of this is LightTables Instarepl and Emacs CIDER inline eval.

## Requirements

At the moment this plugin has support for C# and JavaScript. The underlying C# evalutation is done using the 
Mono csharp repl. The JavaScript implementation makes use of `node --eval`.

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
