package ru.myx.distro.prepare;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

class RepositoryBuildSourceContext {
    private final List<String> classPathNames = new ArrayList<>();

    public final Path cached;

    public final Path distro;

    private final List<String> fetchUrlNames = new ArrayList<>();

    private final List<String> javaCompileList = new ArrayList<>();

    public final DistroBuildSourceContext repositories;
    public final Repository repository;

    public final Path source;

    private final List<String> sourcePathNames = new ArrayList<>();

    RepositoryBuildSourceContext(final Repository repository, final DistroBuildSourceContext repositories) {
	this.repository = repository;
	this.repositories = repositories;
	this.source = repositories.source.resolve(repository.name);
	this.distro = repositories.distro.resolve(repository.name);
	this.cached = repositories.cached.resolve(repository.name);
    }

    public void addJavaClassPath(final Path javaCompileOutputPath) {
	this.repositories.addJavaClassPath(javaCompileOutputPath);
	this.classPathNames.add(javaCompileOutputPath.toString());
    }

    public void addJavaCompileList(final String packageName) {
	this.repositories.addJavaCompileList(this.repository.name + '/' + packageName);
	this.javaCompileList.add(packageName);
    }

    public void addJavaSourcePath(final Path javaCompileInputPath) {
	this.repositories.addJavaSourcePath(javaCompileInputPath);
	this.sourcePathNames.add(javaCompileInputPath.toString());
    }

    void writeOut() throws Exception {

	Files.write(this.cached.resolve("fetch-list.txt"), //
		this.fetchUrlNames, StandardCharsets.UTF_8);

	Files.write(this.cached.resolve("compile-list.txt"), //
		this.javaCompileList, StandardCharsets.UTF_8);

	Files.write(this.cached.resolve("distro-classpath.txt"), //
		this.classPathNames, StandardCharsets.UTF_8);

	Files.write(this.cached.resolve("java-sourcepath.txt"), //
		this.sourcePathNames, StandardCharsets.UTF_8);

    }

}