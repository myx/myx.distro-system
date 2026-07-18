# myx.distro-system

Shared system utilities for the myx.distro build and deployment system.
Provides index building, source/output processing, and shared shell context
utilities used by `myx.distro-source`, `myx.distro-deploy` and related components.

---

## Components:

- **System tools** — index building, project scanning, folder sync/pack operations.
- **Shell scripts** (`sh-scripts/`) — system-level context setup and integration helpers.
- **Shell libs** (`sh-lib/`) — shared context includes used by source and deploy consoles.

---

## Commands:

- `Distro` (from `sh-lib/SystemContext.include`)
	- Dispatches distro system/source/deploy/remote commands in active context.
	- Help: `Distro --help`
- `Action` (from `sh-lib/SystemContext.include`)
	- Runs generated workspace actions from `actions/`.
	- Help: `Action --help`
- `DistroImageDownload` (todo)
	- Fetches published pre-built images during the `image-prepare` stage. Referenced from `distro-source` and `distro-deploy` (see their `image-prepare` stage sections).
	- Not yet implemented.
- `DistroImageSync` (from `sh-scripts/DistroImageSync.fn.sh`)
	- Builds, prints, or executes repo sync task scripts for the source/image pipeline stages (`source-prepare-pull`, `source-process-push`, `image-prepare-pull`, `image-process-push`, `image-install-pull`). Generic sync engine shared across stages/consumers — not stage-specific logic.
	- Help: `DistroImageSync.fn.sh --help`

---

## Update actions:

- `actions/distro/local-tools/apply-distro-system-2-local.sh`
	- Mirrors `source/myx/myx.distro-system` into `.local/myx/myx.distro-system`.
- `actions/distro/system-tools/update-system-tools.sh`
	- Wrapper entrypoint that runs `apply-distro-system-2-local.sh`.

---

## Distro components:

See: [distro](https://github.com/myx/myx.distro?tab=readme-ov-file#myxdistro)
See: [distro-.local](https://github.com/myx/myx.distro-.local?tab=readme-ov-file#myxdistro-.local)
See: [distro-source](https://github.com/myx/myx.distro-source?tab=readme-ov-file#myxdistro-source)
See: [distro-deploy](https://github.com/myx/myx.distro-deploy?tab=readme-ov-file#myxdistro-deploy)
See: [distro-remote](https://github.com/myx/myx.distro-remote?tab=readme-ov-file#myxdistro-remote)