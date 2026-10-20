# Requirements: copy

## Introduction

`copy` is the cmd.exe built-in that copies files and combines several files
into one. This repository recreates it in Loup for Linux, keeping Windows'
operand syntax (`+` joins, `\` separators, `*` and `?` expanded by the
command), its text and binary modes, the overwrite question, messages and
ERRORLEVELs. It uses the shared Windows code in `source/win/` (copied from
loup-cmd-type).

## Requirements

### Requirement 1: Copying

**User Story:** As a cmd user, I want to copy files to a name or a
directory.

#### Acceptance Criteria

1. WHEN the destination is a directory, THE program SHALL copy each source
   file into it under its own name; WHEN it is a new or existing file name,
   to that name; WHEN it is omitted, into the current directory.
2. WHEN a source has `*` or `?` in its last component, THE program SHALL
   copy every matching file (Windows rules, any case); WHEN a source is a
   directory, every file in it; and print each source as typed with `\`.
3. WHEN the destination has `*` or `?`, THE program SHALL name each copy
   with cmd's wildcard rename rules (`*.txt` to `*.bak` gives `a.bak`).
4. THE program SHALL end with `%9d file(s) copied.`
5. A plain copy SHALL be byte for byte, and THE program SHALL check that the
   new file matches its source.

### Requirement 2: Combining

**User Story:** As a cmd user, I want `copy a+b+c all` to concatenate
files.

#### Acceptance Criteria

1. WHEN sources are joined with `+` (attached or as a separate argument),
   or a pattern or directory goes to one file name, THE program SHALL write
   one file holding the sources in order, print each source, and count one
   file.
2. WHEN joined sources have no destination, THE program SHALL append them
   to the first source.
3. `/A` SHALL read a source up to its first Ctrl-Z (0x1A) and end the
   destination with a Ctrl-Z; `/B` SHALL copy bytes as they are. A switch
   SHALL apply to the file just before it and to every later file.
   Combining SHALL default to `/A`, a plain copy to `/B`; an appended file
   takes the mode of the first source.

### Requirement 3: Overwriting and checking

**User Story:** As a cmd user, I want to be asked before a file is
replaced, and to be able to verify copies.

#### Acceptance Criteria

1. WHEN a destination file exists and asking is on, THE program SHALL print
   `Overwrite NAME? (Yes/No/All): ` and read one line of standard input:
   Yes replaces, No skips, All replaces this and every later file; anything
   else asks again; the end of input means No; the answer is echoed when
   standard input is not a terminal.
2. `/Y` SHALL turn asking off, `/-Y` on (the last wins); without either,
   asking SHALL be on unless `COPYCMD` contains `/Y`.
3. `/V` SHALL check every new file against the bytes it should hold.

### Requirement 4: Errors and switches

**User Story:** As a script author, I want Windows' messages and
ERRORLEVELs.

#### Acceptance Criteria

1. WHEN a source is missing or matches nothing, THE program SHALL print
   `The system cannot find the file specified.`; WHEN a directory on the way
   is missing, `The system cannot find the path specified.`; WHEN a wildcard
   is in a directory component, `The filename, directory name, or volume
   label syntax is incorrect.`; then `        0 file(s) copied.` and exit 1.
2. WHEN a file would be copied onto itself, THE program SHALL print `The
   file cannot be copied onto itself.` and exit 1.
3. WHEN there is no source or more than one destination, THE program SHALL
   print `The syntax of the command is incorrect.` and exit 1.
4. `/D`, `/N`, `/Z`, `/L` SHALL be accepted and change nothing; any other
   `/X` SHALL be a name. `/?` SHALL print a short help text; `--help` and
   `--version` alone the help and `copy (loup-cmd-copy) 0.1.0`.
