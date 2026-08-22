# myx.distro-* — AI assistant context

Applies to: myx.distro-.local, myx.distro-deploy, myx.distro-source, myx.distro-system, myx.distro-remote, myx.distro-agents.

Canonical human docs (don't restate here, read them instead):
- Each repo's `README.md` — pipeline stages, folders, variables, `project.inf` properties.
- `myx.distro-.local/sh-lib/help/Man.Project.Inf.file.help.md` — `project.inf` file-format grammar.

This file is reasoning aid + flagged issues, not a rewrite of those docs.

## Repo roles

- `myx.distro-system` — shared kernel (`Distro`/`Require`/`Action`/`DistroSystemContext` in `SystemContext.include`), used by nearly every `.fn.sh`.
- `myx.distro-source` — builds distro indices from source.
- `myx.distro-deploy` — package management/deploy tooling. Requires `myx/myx.distro-source`.
- `myx.distro-remote` — remote-host tooling.
- `myx.distro-agents` — starts a `claude`/`copilot` CLI console (`DistroAgentsConsole.sh`) instead of a bash session. No pipeline builders (console-launcher role, like `-remote`).
- `myx.distro-.local` — bootstraps a fresh workspace, installs the other subsystems. No pipeline builders (boot-only).

Only `myx.distro-source` and `myx.distro-deploy` have shell-side pipeline builders; `-system`/`-remote`/`-agents` don't (kernel/tooling roles).

## Where the mechanics live

Each package's `MAGIC.md` carries the contributor mechanics. This file does not
restate them.

- `myx.distro-system/MAGIC.md` — calling a tool and the three dispatchers, why
  `Distro <name>` fails outside a console, the help-file inconsistencies and the
  ask-before-touching rule, the dependency and index engine, and DistroImageSync
  as direction rather than spec.
- `myx.distro-source/MAGIC.md` — ingest versus build, the change-delta gate,
  builder discovery, and the stage-scoped `MDSC_SOURCE`/`MDSC_CACHED`/`MDSC_OUTPUT`
  values.
- `myx.distro-deploy/MAGIC.md` — picking the narrowest tool, `Execute*` argument
  order, and why exit status is not a deploy result.
- `myx.distro-agents/MAGIC.md` — reaching Slack, email and Trello, adding an
  operation to `DistroAgentsTools.fn.sh`, and its per-operation contracts.
- `myx.distro-remote/MAGIC.md`, `myx.distro-.local/MAGIC.md` — their own package
  notes.
