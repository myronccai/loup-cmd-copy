# loup-cmd-copy

The Windows `copy` command recreated in [Loup](https://code-craft.ai/references/loup):
copy files and combine them (`copy a+b+c all`), with cmd's text and binary
modes, wildcards, `\` paths, overwrite question, messages and ERRORLEVELs,
on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                     # native binary: build/copy
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="a.txt+b.txt c.txt"   # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ build/copy 'demo\part1.txt' 'demo\first.txt'
        1 file(s) copied.
$ build/copy 'demo\part1.txt+demo\part2.txt+demo\part3.txt' 'demo\all.txt'
demo\part1.txt
demo\part2.txt
demo\part3.txt
        1 file(s) copied.
$ od -c demo/all.txt
0000000   h   e   a   d   e   r  \n   b   o   d   y  \n   f   o   o   t
0000020   e   r  \n 032
0000024
$ build/copy /B 'demo\part?.txt' 'demo\all.bin'
demo\part1.txt
demo\part2.txt
demo\part3.txt
        1 file(s) copied.
$ build/copy 'demo\part*.txt' 'demo\backup'
demo\part1.txt
Overwrite demo\backup\part1.txt? (Yes/No/All): n
demo\part2.txt
demo\part3.txt
        2 file(s) copied.
$ build/copy 'demo\*.txt' 'demo\*.bak'
demo\all.txt
demo\first.txt
demo\part1.txt
demo\part2.txt
demo\part3.txt
        5 file(s) copied.
$ (cd build/demo && ../copy part1.txt); echo "ERRORLEVEL $?"
The file cannot be copied onto itself.
        0 file(s) copied.
ERRORLEVEL 1
$ build/copy 'demo\missing.txt' demo
The system cannot find the file specified.
        0 file(s) copied.
```

(`032` is the Ctrl-Z that text mode puts at the end of a combined file.)
