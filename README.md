# myx.distro-system

Indexing and query tools shared by every myx.distro console. Use them to find
projects, read project metadata, resolve build order, and sync source
repositories.

Use it from any source or deploy console. You do not install it on its own. It
comes with those toolsets.

## First command

Open a console, then list every project in the workspace:

	./DistroSourceConsole.sh
	ListDistroProjects.fn.sh --all-projects

## Documentation

- [Installation](docs/installation.md) — requirements, install, upgrade and uninstall.
- [Configuration](docs/configuration.md) — settings, profile options and configuration commands.
- [Use](docs/use.md) — getting started, common tasks and selecting what to act on.
- [Commands](docs/commands.md) — the command reference.
- [Formats](docs/formats.md) — file formats, directives, stages and folder layout.
- [Extension](docs/extension.md) — adding your own members, builders, directives and commands.
- [Examples](docs/examples.md) — worked examples from start to finish.
- [Troubleshooting](docs/troubleshooting.md) — symptoms, causes and actions.

## Getting help

- `<Tool>.fn.sh --help` — full syntax, options and examples for any command above.
- `Distro --help`, `Action --help`, `Require --help` — dispatcher syntax.
- Press TAB after a command name and a space for shell completion.

## Related packages

- [myx.distro](https://github.com/myx/myx.distro) — the distro system overview.
- [myx.distro-.local](https://github.com/myx/myx.distro-.local) — install and launch the toolsets.
- [myx.distro-source](https://github.com/myx/myx.distro-source) — build source into a distro image.
- [myx.distro-deploy](https://github.com/myx/myx.distro-deploy) — deploy a distro image to hosts.
- [myx.distro-remote](https://github.com/myx/myx.distro-remote) — drive a workspace on another machine.
- [myx.distro-agents](https://github.com/myx/myx.distro-agents) — the magic-team agents and their tooling.
