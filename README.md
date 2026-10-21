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

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                     # native binary: build/copy
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="a.txt+b.txt c.txt"   # run from source (Stage0's interpreter)
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

## Options

```text
COPY [/V] [/Y | /-Y] [/A | /B] source [/A | /B] [+ source [/A | /B] ...]
     [destination [/A | /B]]
```

- **source** is a file, a pattern with `*` and `?` (Windows rules, any
  case), or a directory (its files). Join sources with `+` (`a+b`, `a + b`)
  to combine them into one file.
- **destination** is a directory (the files keep their names), a file name,
  or a pattern such as `*.bak` (each copy is named by cmd's wildcard rename
  rules). Without it, files go to the current directory, and joined sources
  are appended to the first one. A pattern or directory copied to one file
  name is combined into that file.
- `/A` (text) and `/B` (binary) apply to the file just before them and to
  every later one. In text mode a source ends at its first Ctrl-Z and the
  destination gets one at the end. Text is the default when combining,
  binary for a plain copy.
- `/V` reads each new file back and compares it with its sources.
- `/Y` replaces existing files without asking and `/-Y` always asks. Without
  either, copy asks unless the `COPYCMD` environment variable contains `/Y`.
  The question `Overwrite PATH? (Yes/No/All):` reads one line of standard
  input (`y`, `n` or `a`).
- `/D /N /Z /L` are accepted and change nothing.

Switches start with `/` or `-` in any case. A `/X` that is not one of the
switches above is a path, and `--` ends switch parsing. `/?` prints a short
help; `--help` and `--version` work as the only argument.

Exit status (ERRORLEVEL): `0` when every file was copied (also when you
declined an overwrite), `1` for a usage error, a missing source, a copy onto
itself, or a file that could not be written.

## Differences from the original

- The overwrite answer is a whole line (Enter needed); cmd reacts to the key
  press. When standard input is not a terminal, the answer is echoed after
  the question. Without `/Y`, copy asks even inside scripts; pass `/Y` or set
  `COPYCMD=/Y` there.
- No timestamps or attributes are kept: a copy gets the time it was written.
- Combined files are built in memory.
- A destination that is also a later source keeps its old content in the
  combined result.
- The wording of the `/V` failure message is this recreation's own.
- Names are case-sensitive on Linux for literal operands; patterns ignore
  case.
- `/?` prints a short help text of this recreation, not Windows' own.
  Messages end with LF, not CRLF.
- `make run` uses Stage0's interpreter (`loup-bootstrap run`), where a child
  process gets no standard input: `Overwrite X? (Yes/No/All):` is answered No
  there, so use `/Y`. Under the self-hosted `loup run` the question
  would repeat forever.

## Layout

```text
source/main.loup                # entry point
source/appinfo.loup             # name, version, exit statuses
source/cli/args.loup            # the + grammar, positional /A and /B, COPYCMD
source/cli/usage.loup           # /? and --version text
source/cli/app.loup             # run(): parse, dispatch, exit status
source/commands/plan.loup       # plan_copy(): sources, destination, jobs
source/commands/copy.loup       # run_copy(): write each job, the summary line
source/commands/content.loup    # text and binary reads, checked writes
source/commands/transform.loup  # cmd's wildcard rename rules (*.txt -> *.bak)
source/commands/prompt.loup     # the Overwrite question, one line of stdin at a time
source/commands/cwd.loup        # absolute paths for messages ($PWD or pwd)
source/win/                     # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup               # unit tests (make test)
tests/e2e.sh                    # end-to-end tests of build/copy (make e2e)
specs/copy/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
