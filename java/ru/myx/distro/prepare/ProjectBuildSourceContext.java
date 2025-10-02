package ru.myx.distro.prepare;

import java.nio.file.Path;

class ProjectBuildSourceContext {
    public final Path cached;
    public final Path distro;

    public final Project project;

    public final Path source;

    ProjectBuildSourceContext(final Project project, final RepositoryBuildSourceContext ctx) {
	this.project = project;
	this.source = ctx.source.resolve(project.name);
	this.distro = ctx.distro.resolve(project.name);
	this.cached = ctx.cached.resolve(project.name);
    }

    ProjectBuildSourceContext(final Project project, final DistroBuildSourceContext ctx) {
	this.project = project;
	this.source = ctx.source.resolve(project.repo.name).resolve(project.name);
	this.distro = ctx.distro.resolve(project.repo.name).resolve(project.name);
	this.cached = ctx.cached.resolve(project.repo.name).resolve(project.name);
    }
}