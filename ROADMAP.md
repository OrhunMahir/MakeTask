# MakeTask Roadmap

This file records accepted product and developer-experience work together with its implementation status.

## Completed

### One-command terminal launcher

**Goal:** Start MakeTask from any terminal directory by typing only:

```sh
maketask
```

The user must not need to locate the repository, run `cd`, remember an Xcode command, or manually open a build product.

Planned acceptance criteria:

- Provide a one-time installer for a small `maketask` executable in the user's `PATH`.
- `maketask` opens the installed `/Applications/MakeTask.app` immediately.
- Provide a developer mode, such as `maketask --dev`, that builds and opens the Debug app from the MakeTask repository without changing directories manually.
- Prefer `~/.local/bin` so installation does not require `sudo`.
- Detect a missing app, missing repository, or failed build and show a clear error.
- Include an uninstall command or documented removal step.
- Do not depend on a shell-specific alias.

**Status:** Completed on 2026-08-27.

The implementation lives in `scripts/maketask`, with one-time installation and removal handled by `scripts/install-maketask.sh` and `scripts/uninstall-maketask.sh`. It supports normal installed-app launching, `--dev`, `--install-app`, path overrides, missing-path diagnostics, and installation without a shell alias or `sudo`.
