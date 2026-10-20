# Design: copy

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them,
handles `/?` and `--version`, and calls `commands.copy.run_copy`.
`run_copy` asks `plan_copy` for a plan (jobs, or one error message), then
carries out each job: it prints the source names, refuses a copy onto
itself, asks before overwriting, writes, checks, and prints the summary.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 and 1) |
| `source/cli/args.loup` | `FileArg`, `Options`, `copy_switches()`, `parse_args` (the `+` grammar, positional modes), `copycmd_confirm`, `should_ask` |
| `source/cli/usage.loup` | `usage()` (a short help text), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/plan.loup` | `SourceFile`, `Job`, `Plan`, `plan_copy` |
| `source/commands/copy.loup` | `summary_line`, `job_bytes`, `write_job`, `run_copy` |
| `source/commands/content.loup` | `append_file`, `finish`, `write_checked`, `holds`, `same_files` |
| `source/commands/transform.loup` | `transform_name` (cmd's wildcard rename rules) |
| `source/commands/prompt.loup` | the Overwrite question (one line of stdin through `sh`) |
| `source/commands/cwd.loup` | `absolute_path`, `current_dir` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### Parsing

The shared parser finds `/?`, `--help`, `--version` and bad values. Then
each argument is classified on its own (`parse_switches([arg])`): switches
update the confirm setting, `/V`, and the current mode (`/A`, `/B`), which
also goes back to the file just before; every operand is split at `+` into
a stream of names and pluses. The grammar is `NAME (+ NAME)* [NAME]`:
anything after the destination is a syntax error.

### Planning

Each source becomes files: a pattern through `win.wildcard.expand`
(files), a directory through `list_matches(dir, "*", MATCH_FILES)`, or the
file itself; the first failing source stops the plan with its message. The
destination is a directory, a pattern, or a file name (whose directory must
exist). Copy combines when sources were joined or a pattern/directory goes
to one file name; then one job reads every source (text by default), else
one job per file (binary by default). A pattern destination names each
copy with `transform_name(base, mask)`.

### Writing

A binary one-to-one job uses `io.fs.copy` and then compares the files byte
by byte (native file operations fail silently). Other jobs build the bytes
as a `list[int]` (`append_file` stops at Ctrl-Z in text mode, `finish`
adds one for a text destination), write them with
`writeBytes(path, bytesFromInts(...))` and read them back. Loup 1.26.0 has
no bytes concatenation, and native `bytes == bytes` is unreliable, hence
the lists and the byte loops.

### The wildcard transform

`transform_name` walks the mask: `?` copies a source character unless it
is `.` or the end; `*` at the end or before `?` copies the rest; `*c`
copies through the last `c` (or the rest plus `c`); `.` skips through the
next source `.`; other characters replace one source character. Trailing
dots and spaces are dropped.

## Differences from the original

- Answers need Enter; copy asks in scripts too unless `/Y`/`COPYCMD=/Y`;
  non-terminal answers are echoed.
- No timestamps are kept; `/D /N /Z /L` change nothing.
- Combined files are built in memory.
- A destination that is also a later source keeps its old content.
- `/V` failure wording is this recreation's.
- `/?` prints this recreation's own short help text.

## Error handling

Plan errors print the message and `0 file(s) copied.` and give status 1.
A failing job prints its message, the others go on, and the status is 1.
Declining an overwrite is not an error. An unexpected exception is printed
on standard error and gives status 1.

## Testing

- `tests/args_test.loup`: `+` forms, syntax errors, positional modes,
  switches, `COPYCMD`.
- `tests/transform_test.loup`: a table of names and masks.
- `tests/plan_test.loup`: plain copies, combining, appending, every error.
- `tests/content_test.loup`, `tests/copy_test.loup`: text and binary reads,
  writing and checking, the summary.
- `tests/prompt_test.loup`, `tests/cwd_test.loup`, `tests/app_test.loup`.
- `tests/e2e.sh`: the native binary; every case starts from a fresh tree
  under `$TMP` and checks the tree afterwards (contents through `cat -v`,
  so a Ctrl-Z shows as `^Z`).
