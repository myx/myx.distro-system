package ru.myx.distro.prepare;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Set;

import ru.myx.distro.ClasspathBuilder;
import ru.myx.distro.OperationContext;
import ru.myx.distro.Utils;

public final class Distro {
    private final Map<String, Project> byProjectName = new HashMap<>();

    private final Map<String, Set<Project>> byDeclares = new LinkedHashMap<>();

    private final Map<String, Set<Project>> byAugments = new LinkedHashMap<>();

    private final Map<String, Set<Project>> byKeywords = new LinkedHashMap<>();

    private final Map<String, Set<Project>> byProvides = new LinkedHashMap<>();

    private final Map<String, Repository> byRepositoryName = new HashMap<>();

    private final List<Project> sequenceProjects = new ArrayList<>();

    public Distro() {
	//
    }

    boolean addKnown(final Project project) {
	// this.byProjectName.put(project.getName(), project);
	this.byProjectName.put(project.getFullName(), project);
	return true;
    }

    boolean addKnown(final Repository repo) {
	this.byRepositoryName.put(repo.getName(), repo);
	return true;
    }

    public void addDeclares(final Project project, final OptionListItem provides) {
	Set<Project> set = this.byDeclares.get(provides.getName());
	if (set == null) {
	    set = new HashSet<>();
	    this.byDeclares.put(provides.getName(), set);
	}
	set.add(project);
    }

    public void addAugments(final Project project, final OptionListItem augments) {
	Set<Project> set = this.byAugments.get(augments.getName());
	if (set == null) {
	    set = new HashSet<>();
	    this.byAugments.put(augments.getName(), set);
	}
	set.add(project);
    }

    public void addKeywords(final Project project, final OptionListItem provides) {
	Set<Project> set = this.byKeywords.get(provides.getName());
	if (set == null) {
	    set = new HashSet<>();
	    this.byKeywords.put(provides.getName(), set);
	}
	set.add(project);
    }

    public void addProvides(final Project project, final OptionListItem provides) {
	Set<Project> set = this.byProvides.get(provides.getName());
	if (set == null) {
	    set = new HashSet<>();
	    this.byProvides.put(provides.getName(), set);
	}
	set.add(project);
    }

    public boolean buildCalculateSequence(final OperationContext context, List<Project> buildQueue) {
	final Map<String, Project> checked = new HashMap<>();
	this.sequenceProjects.clear();
	for (final Project project : (buildQueue != null ? buildQueue : this.byProjectName.values())) {
	    project.buildCalculateSequence(context, this.sequenceProjects, checked);
	}
	return true;
    }

    public void buildPrepareCompileIndex(final OperationContext context, final Path outputTarget) throws Exception {
	this.buildPrepareDistroIndex(context, outputTarget, false, true);

	final List<String> compileJava = new ArrayList<>();
	final ClasspathBuilder classpath = new ClasspathBuilder();

	for (final Repository repo : this.byRepositoryName.values()) {
	    repo.buildPrepareDistroIndex(context, this, outputTarget.resolve(repo.name), true);
	}
	for (final Project project : this.sequenceProjects) {
	    project.buildPrepareCompileIndex(context, outputTarget.resolve(project.repo.name).resolve(project.name),
		    compileJava);
	    project.buildPrepareCompileIndexMakeClasspath(classpath);
	}

	Utils.save(//
		context.console, //
		outputTarget.resolve("distro-classpath.txt"), //
		classpath//
	);

	Utils.save(//
		context.console, //
		outputTarget.resolve("distro-sequence.txt"), //
		this.sequenceProjects.stream().map(Project::projectFullName)//
	);
    }

    public void buildPrepareDistroIndex(//
	    final OperationContext context, final Path outputTarget, final boolean deep, final boolean full//
    ) throws Exception {
	if (!Files.isDirectory(outputTarget)) {
	    throw new IllegalStateException("outputTarget is not a folder, " + outputTarget);
	}

	{
	    final List<String> repositoryNames = new ArrayList<>();
	    {
		for (final Repository repo : this.byRepositoryName.values()) {
		    repositoryNames.add(repo.getName());
		}
	    }

	    Files.write(outputTarget.resolve("distro-namespaces.txt"), repositoryNames, StandardCharsets.UTF_8);
	}

	if (deep) {
	    for (final Repository repo : this.byRepositoryName.values()) {
		repo.buildPrepareDistroIndex(context, this, outputTarget.resolve(repo.name), full);
	    }
	    for (final Project project : this.sequenceProjects) {
		project.buildPrepareDistroIndex(//
			context, //
			outputTarget.resolve(project.repo.name).resolve(project.name), //
			true, //
			full//
		);
	    }
	}

	{
	    final Properties info = new Properties();
	    {
		final StringBuilder builder = new StringBuilder(256);
		for (final Repository repository : this.byRepositoryName.values()) {
		    builder.append(repository.name).append(' ');
		    info.setProperty("REP-" + repository.name.trim(), repository.fetch.trim());
		}
		info.setProperty("REPS", builder.toString().trim());
	    }
	    {
		final StringBuilder builder = new StringBuilder(256);
		for (final Project project : this.sequenceProjects) {
		    builder.append(project.repo.name).append('/').append(project.name).append(' ');
		    project.buildPrepareDistroIndexFillProjectInfo(context, info);
		}
		info.setProperty("PRJS", builder.toString().trim());
	    }
	    {
		final Map<String, Set<Project>> provides = this.getProvides();
		for (final String provide : provides.keySet()) {
		    final StringBuilder builder = new StringBuilder(256);
		    for (final Project project : provides.get(provide)) {
			builder.append(project.repo.name).append('/').append(project.name).append(' ');
		    }
		    // not really needed (yet?)
		    // info.setProperty("PRV-" + provide, builder.toString().trim());
		}
	    }

	    Utils.save(//
		    context.console, //
		    outputTarget.resolve("distro-index.inf"), //
		    info, //
		    "Generated by ru.myx.distro.prepare", //
		    true//
	    );
	}
	{
	    Utils.save(//
		    context.console, //
		    outputTarget.resolve("distro-sequence.txt"), //
		    this.sequenceProjects.stream().map(Project::projectFullName)//
	    );
	}
    }

    public boolean buildPrepareIndexFromSource(final Path outputRoot, final Path sourceRoot) throws Exception {
	final DistroBuildSourceContext ctx = new DistroBuildSourceContext(outputRoot, sourceRoot);
	{
	    for (final Repository repository : this.byRepositoryName.values()) {
		final RepositoryBuildSourceContext repositoryCtx = new RepositoryBuildSourceContext(repository, ctx);
		ctx.repos.put(repository, repositoryCtx);

		final Path source = repositoryCtx.source;
		if (!Files.isDirectory(source)) {
		    throw new IllegalStateException("source is not a folder, " + source);
		}

		final Path distro = repositoryCtx.distro;
		Files.createDirectories(distro);
		if (!Files.isDirectory(distro)) {
		    throw new IllegalStateException("distro is not a folder, " + distro);
		}

		final Path cached = repositoryCtx.cached;
		Files.createDirectories(cached);
		if (!Files.isDirectory(cached)) {
		    throw new IllegalStateException("cached is not a folder, " + cached);
		}

		{
		    Files.copy(//
			    source.resolve("repository.inf"), //
			    distro.resolve("repository.inf"), //
			    StandardCopyOption.REPLACE_EXISTING);
		}
	    }
	    for (final Project project : this.sequenceProjects) {
		project.buildSource(ctx);
	    }
	    for (final RepositoryBuildSourceContext repositoryCtx : ctx.repos.values()) {
		repositoryCtx.writeOut();
	    }
	}
	ctx.writeOut();
	return true;
    }

    void compileAllJavaSource(final MakeCompileJava javaCompiler) throws Exception {

	for (final Repository repository : this.byRepositoryName.values()) {
	    repository.compileAllJavaSource(javaCompiler);
	}
    }

    public Project getProject(final String name) {
	final int pos = name.indexOf('/');
	if (pos == -1) {
	    for (final Repository repo : this.byRepositoryName.values()) {
		final Project proj = repo.getProject(name);
		if (proj != null) {
		    return proj;
		}
	    }
	    return null;
	}
	{
	    final Project project = this.byProjectName.get(name);
	    if (project != null) {
		return project;
	    }
	}
	{
	    final String repositoryName = name.substring(0, pos);
	    final Repository repo = this.byRepositoryName.get(repositoryName);
	    if (repo == null) {
		return null;
	    }
	    return repo.getProject(name.substring(pos + 1));
	}
    }

    public Map<String, Project> getProjects() {
	final Map<String, Project> result = new LinkedHashMap<>();
	result.putAll(this.byProjectName);
	return result;
    }

    public Map<String, Set<Project>> getDeclares() {
	final Map<String, Set<Project>> result = new LinkedHashMap<>();
	result.putAll(this.byDeclares);
	return result;
    }

    public Map<String, Set<Project>> getKeywords() {
	final Map<String, Set<Project>> result = new LinkedHashMap<>();
	result.putAll(this.byKeywords);
	return result;
    }

    public Map<String, Set<Project>> getAugments() {
	final Map<String, Set<Project>> result = new LinkedHashMap<>();
	result.putAll(this.byAugments);
	return result;
    }

    public Map<String, Set<Project>> getProvides() {
	final Map<String, Set<Project>> result = new LinkedHashMap<>();
	result.putAll(this.byProvides);
	return result;
    }

    public Set<Project> getDeclares(final OptionListItem name) {
	final String requireString = name.getName();
	final Project projectExact = this.getProject(requireString);
	if (projectExact != null) {
	    return Collections.singleton(projectExact);
	}
	return this.byDeclares.get(requireString);
    }

    public Set<Project> getAugments(final OptionListItem name) {
	final String requireString = name.getName();
	final Project projectExact = this.getProject(requireString);
	if (projectExact != null) {
	    return Collections.singleton(projectExact);
	}
	return this.byAugments.get(requireString);
    }

    public Set<Project> getKeywords(final OptionListItem name) {
	final String requireString = name.getName();
	final Project projectExact = this.getProject(requireString);
	if (projectExact != null) {
	    return Collections.singleton(projectExact);
	}
	return this.byKeywords.get(requireString);
    }

    public Set<Project> getProvides(final OptionListItem name) {
	final String requireString = name.getName();
	final Project projectExact = this.getProject(requireString);
	if (projectExact != null) {
	    return Collections.singleton(projectExact);
	}
	return this.byProvides.get(requireString);
    }

    public Iterable<Repository> getRepositories() {
	return this.byRepositoryName.values();
    }

    public Repository getRepository(final String name) {
	return this.byRepositoryName.get(name);
    }

    public Iterable<Project> getSequenceProjects() {
	return this.sequenceProjects;
    }

    public void reset() {
	this.byRepositoryName.clear();
	this.byProjectName.clear();
	this.sequenceProjects.clear();
    }
}
