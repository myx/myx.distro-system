package ru.myx.distro.prepare;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class DistroBuildSourceContext {

    private final List<String> classPathNames = new ArrayList<>();
    public final Path cached;
    public final Path distro;

    private final List<String> fetchFileNames = new ArrayList<>();

    private final List<String> javaCompileList = new ArrayList<>();
    public final Path output;
    public final Path source;
    private final List<String> sourcePathNames = new ArrayList<>();

    Map<Repository, RepositoryBuildSourceContext> repos = new HashMap<>();

    DistroBuildSourceContext(final Path output, final Path source) {
	this.output = output;
	this.source = source;
	this.distro = output.resolve("distro");
	this.cached = output.resolve("distro");
    }

    public void addJavaClassPath(final Path javaCompileOutputPath) {
	this.classPathNames.add(javaCompileOutputPath.toString());
    }

    public void addJavaCompileList(final String packageName) {
	this.javaCompileList.add(packageName);
    }

    public void addJavaSourcePath(final Path javaCompileInputPath) {
	this.sourcePathNames.add(javaCompileInputPath.toString());
    }

    void writeOut() throws Exception {

	Files.write(this.cached.resolve("fetch-list.txt"), //
		this.fetchFileNames, StandardCharsets.UTF_8);

	Files.write(this.cached.resolve("compile-list.txt"), //
		this.javaCompileList, StandardCharsets.UTF_8);

	Files.write(this.cached.resolve("distro-classpath.txt"), //
		this.classPathNames, StandardCharsets.UTF_8);

	Files.write(this.cached.resolve("java-sourcepath.txt"), //
		this.sourcePathNames, StandardCharsets.UTF_8);

    }

}