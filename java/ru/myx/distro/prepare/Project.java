package ru.myx.distro.prepare;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.util.TreeMap;

import ru.myx.distro.ClasspathBuilder;
import ru.myx.distro.OperationContext;
import ru.myx.distro.Utils;

public class Project {
    public static boolean checkIfProject(final Path projectRoot) {
	final String folderName = projectRoot.getFileName().toString();
	if (folderName.length() < 2 || folderName.charAt(0) == '.') {
	    // not a user-folder, hidden
	    return false;
	}
	if (!Files.isDirectory(projectRoot)) {
	    return false;
	}
	final Path infPath = projectRoot.resolve("project.inf");
	if (!Files.isRegularFile(infPath)) {
	    return false;
	}
	return true;
    }

    public static String projectFullName(final Project project) {
	return project.repo.name + '/' + project.name;
    }

    public static String projectName(final Project project) {
	return project.getName();
    }

    static Project staticLoadFromLocalIndex(final Repository repo, final String projectName, final Path projectRoot)
	    throws Exception {

	final Path infPath = projectRoot.resolve("project.inf");
	if (!Files.isRegularFile(infPath)) {
	    // doesn't have a manifest
	    return null;
	}
	final Properties info = new Properties();
	try (final InputStream in = Files.newInputStream(infPath)) {
	    info.load(in);
	}

	return new Project(projectName, info, repo);
    }

    static Project staticLoadFromLocalSource(final ConsoleOutput console, final Repository repo,
	    final String packageName, final Path projectPath) throws Exception {
	final String folderName = projectPath.getFileName().toString();
	if (folderName.length() < 2 || folderName.charAt(0) == '.') {
	    // not a user-folder, hidden
	    return null;
	}
	final Path infPath = projectPath.resolve("project.inf");
	if (!Files.isRegularFile(infPath)) {
	    // doesn't have a manifest
	    return null;
	}
	final Properties info = new Properties();
	try (final InputStream in = Files.newInputStream(infPath)) {
	    info.load(in);
	}
	final String checkName = info.getProperty("Name", "").trim();
	if (checkName.length() == 0) {
	    // 'Name' is mandatory
	    System.err.println(Project.class.getSimpleName() + ": skipped, no 'Name' in project.inf");
	    return null;
	}
	if (!checkName.equals(packageName) && !packageName.endsWith('/' + checkName)) {
	    console.outError( //
		    "ERROR: " + Project.class.getSimpleName() + ": packageName mismatch: " //
			    + packageName + " != " + checkName//
	    );
	    return null;
	}
	final Project project = new Project(packageName, info, repo);
	project.projectSourceRoot = projectPath;
	return project;
    }

    private static void updateList(final String[] items, final List<String> list) {
	for (final String item : items) {
	    final String x = item.trim();
	    if (x.length() > 0) {
		list.add(x);
	    }
	}
    }

    private static void updateList(final String[] items, final OptionList list) {
	for (final String item : items) {
	    final String x = item.trim();
	    if (x.length() > 0) {
		list.add(new OptionListItem(x));
	    }
	}
    }

    private final List<String> lstContains = new ArrayList<>();

    private final OptionList lstDeclares = new OptionList();

    private final OptionList lstKeywords = new OptionList();

    private final OptionList lstProvides = new OptionList();

    private final OptionList lstRequires = new OptionList();

    private final OptionList lstAugments = new OptionList();

    public final String name;

    /**
     * Initialized only for projects loaded from local source
     */
    public Path projectSourceRoot = null;

    public final Repository repo;

    Project(final String name, final Properties info, final Repository repo) {
	this.repo = repo;
	this.name = name.trim();
	this.lstDeclares.add(new OptionListItem(this.getFullName()));
	this.lstKeywords.add(new OptionListItem(this.getName()));
	this.lstProvides.add(new OptionListItem(this.getName()));
	this.lstProvides.add(new OptionListItem(this.getFullName()));
	this.lstAugments.add(new OptionListItem(this.getFullName()));
	if (info != null) {
	    Project.updateList(info.getProperty("Declares", "").split("\\s+"), this.lstDeclares);
	    Project.updateList(info.getProperty("Keywords", "").split("\\s+"), this.lstKeywords);
	    Project.updateList(info.getProperty("Provides", "").split("\\s+"), this.lstProvides);
	    Project.updateList(info.getProperty("Requires", "").split("\\s+"), this.lstRequires);
	    Project.updateList(info.getProperty("Augments", "").split("\\s+"), this.lstAugments);
	}
	if (repo != null) {
	    repo.addKnown(this);
	    if (repo.distro != null) {
		repo.distro.addKnown(this);
	    }
	}
    }

    public List<Project> buildCalculateSequence(final OperationContext context, final List<Project> sequence,
	    final Map<String, Project> seen) {
	if (seen.putIfAbsent(this.getFullName(), this) != null) {
	    return sequence;
	}

	final Map<String, Project> know = new TreeMap<>();
	final LinkedList<Project> queue = new LinkedList<>();
	queue.addLast(this);

	final Distro distro = this.repo.distro;

	queue: for (;;) {
	    final Project project = queue.peekFirst();
	    if (project == null) {
		// done
		return sequence;
	    }

	    if (know.containsKey(project.getFullName())) {
		queue.removeFirst();
		continue queue;
	    }

	    for (final OptionListItem requires : project.lstRequires) {
		final Set<Project> providers = distro.getProvides(requires);
		if (providers == null) {
		    if (context.noFail) {
			context.console
				.outError("ERROR: required item is unknown, name: " + requires + " for " + this.name);
			continue;
		    }
		    throw new IllegalArgumentException(
			    "required item is unknown, name: " + requires + " for " + this.name);
		}

		for (final Project provider : providers) {
		    if (seen.putIfAbsent(provider.getFullName(), provider) == null) {
			queue.addFirst(provider);
			continue queue;
		    }
		}
	    }

	    queue.removeFirst();
	    if (know.putIfAbsent(project.getFullName(), project) == null) {
		sequence.add(project);
	    }

	    continue queue;
	}
    }

    public void buildPrepareCompileIndex(final OperationContext context, final Path projectOutput,
	    final List<String> compileJava) throws Exception {
	this.buildPrepareDistroIndex(context, projectOutput, false, false);

	Utils.save(//
		context.console, //
		projectOutput.resolve("project-classpath.txt"), //
		this.buildPrepareCompileIndexMakeClasspath(new ClasspathBuilder())//
	);

	if (this.projectSourceRoot == null) {
	    return;
	}

	{
	    final Path dataSourcePath = this.projectSourceRoot.resolve("java");
	    if (Files.isDirectory(dataSourcePath)) {
		final Path dataOutputPath = projectOutput.resolve("java");
		Files.createDirectories(dataOutputPath);

		final List<Path> sources = new ArrayList<>();
		sources.add(dataSourcePath);

		{
		    final Path bin = this.projectSourceRoot.resolve("bin");
		    if (Files.isDirectory(bin)) {
			sources.add(bin);
		    }
		}

		Utils.sync(context.console, //
			sources, //
			dataOutputPath //
		);
	    }
	}
	{
	    for (final String type : new String[] { "data", "docs", "host", "jars", "image-process" }) {
		final Path dataSourcePath = this.projectSourceRoot.resolve(type);
		if (Files.isDirectory(dataSourcePath)) {
		    final Path dataOutputPath = projectOutput.resolve(type);
		    Files.createDirectories(dataOutputPath);
		    Utils.sync(context.console, //
			    Arrays.asList(dataSourcePath), //
			    dataOutputPath //
		    );
		}
	    }
	}
    }

    public ClasspathBuilder buildPrepareCompileIndexMakeClasspath(final ClasspathBuilder list) {
	if (this.projectSourceRoot == null) {
	    for (final String item : this.lstContains) {
		if (item.startsWith("jars/")) {
		    list.add(this.repo.name + '/' + this.name + '/' + item);
		    continue;
		}
		if (item.startsWith("java.jar")) {
		    list.add(this.repo.name + '/' + this.name + '/' + item);
		    continue;
		}
	    }
	} else {
	    for (final String item : this.lstContains) {
		if (item.startsWith("jars/")) {
		    list.add(this.repo.name + '/' + this.name + '/' + item);
		    continue;
		}
		if (item.startsWith("java.jar")) {
		    list.add(this.repo.name + '/' + this.name + "/java/");
		    continue;
		}
	    }
	}
	return list;
    }

    public void buildPrepareDistroIndex(//
	    final OperationContext context, final Path packageOutput, final boolean deep, final boolean full//
    ) throws Exception {
	Files.createDirectories(packageOutput);
	if (!Files.isDirectory(packageOutput)) {
	    throw new IllegalStateException("packageOutput is not a folder, " + packageOutput);
	}

	if (full) {
	    final Properties info = new Properties();
	    info.setProperty("Name", this.getFullName());
	    info.setProperty("Declares", this.lstDeclares.toString());
	    info.setProperty("Keywords", this.lstKeywords.toString());
	    info.setProperty("Provides", this.lstProvides.toString());
	    info.setProperty("Requires", this.lstRequires.toString());
	    info.setProperty("Augments", this.lstAugments.toString());

	    Utils.save(//
		    context.console, //
		    packageOutput.resolve("project.inf"), //
		    info, //
		    "Generated by ru.myx.distro.prepare", //
		    true//
	    );
	}

	{
	    final Properties info = new Properties();
	    info.setProperty("PROJ", this.getFullName());
	    info.setProperty("PRJS", this.getFullName());
	    this.buildPrepareDistroIndexFillProjectInfo(context, info);

	    Utils.save(//
		    context.console, //
		    packageOutput.resolve("project-index.env.inf"), //
		    info, //
		    "Generated by ru.myx.distro.prepare", //
		    true//
	    );
	}

	if (full) {
	    final Collection<String> lines = new LinkedHashSet<>();
	    {
		lines.add(/* project.getFullName() + ' ' + */this.name);
		for (final OptionListItem item : this.getProvides()) {
		    item.fillList(this.getFullName() + ' ', lines);
		}
	    }
	    Utils.save(//
		    context.console, //
		    packageOutput.resolve("project-provides.txt"), //
		    lines.stream()//
	    );
	}
	if (full) {
	    final Collection<String> lines = new LinkedHashSet<>();
	    {
		lines.add(/* project.getFullName() + ' ' + */this.name);
		for (final OptionListItem item : this.getDeclares()) {
		    item.fillList(this.getFullName() + ' ', lines);
		}
	    }
	    Utils.save(//
		    context.console, //
		    packageOutput.resolve("project-declares.txt"), //
		    lines.stream()//
	    );
	}
	if (full) {
	    final Collection<String> lines = new LinkedHashSet<>();
	    {
		lines.add(/* project.getFullName() + ' ' + */this.name);
		for (final OptionListItem item : this.getKeywords()) {
		    item.fillList(this.getFullName() + ' ', lines);
		}
	    }
	    Utils.save(//
		    context.console, //
		    packageOutput.resolve("project-keywords.txt"), //
		    lines.stream()//
	    );
	}

	if (full) {
	    Utils.save(//
		    context.console, //
		    packageOutput.resolve("project-sequence.txt"), //
		    this.getBuildSequence(context).stream().map(Project::projectFullName)//
	    );
	}
    }

    void buildPrepareDistroIndexFillProjectInfo(final OperationContext context, final Properties info)
	    throws Exception {
	info.setProperty("PRJ-DCL-" + this.getFullName(), //
		this.lstDeclares.toString());
	info.setProperty("PRJ-KWD-" + this.getFullName(), //
		this.lstKeywords.toString());
	info.setProperty("PRJ-AUG-" + this.getFullName(), //
		this.lstAugments.toString());
	info.setProperty("PRJ-REQ-" + this.getFullName(), //
		this.lstRequires.toString());
	info.setProperty("PRJ-PRV-" + this.getFullName(), //
		this.lstProvides.toString());
	info.setProperty("PRJ-SEQ-" + this.getFullName(), //
		this.getBuildSequence(context).stream()//
			.map(Project::projectFullName)//
			.reduce("", (t, u) -> t + " " + u).trim()//
	);
	info.setProperty("PRJ-GET-" + this.getFullName(), //
		this.lstContains.stream()//
			.reduce("", (t, u) -> u + ' ' + t).trim()//
	);
    }

    public boolean buildSource(final DistroBuildSourceContext ctx) throws Exception {

	final ProjectBuildSourceContext projectContext = new ProjectBuildSourceContext(this, ctx);

	final Path source = projectContext.source;
	if (!Files.isDirectory(source)) {
	    throw new IllegalStateException("source is not a folder, " + source);
	}

	final Path distro = projectContext.distro;
	Files.createDirectories(distro);
	if (!Files.isDirectory(distro)) {
	    throw new IllegalStateException("distro is not a folder, " + distro);
	}

	{
	    Files.copy(//
		    source.resolve("project.inf"), //
		    distro.resolve("project.inf"), //
		    StandardCopyOption.REPLACE_EXISTING);
	}

	final Path javaSourcePath = projectContext.source.resolve("java");
	if (Files.isDirectory(javaSourcePath)) {

	    final Path cached = projectContext.cached;
	    Files.createDirectories(cached);
	    if (!Files.isDirectory(cached)) {
		throw new IllegalStateException("cached is not a folder, " + cached);
	    }

	    ctx.addJavaCompileList(this.name);

	    ctx.addJavaSourcePath(javaSourcePath);

	    final Path javaCompilePath = projectContext.cached.resolve("java");
	    Files.createDirectories(javaCompilePath);
	    if (!Files.isDirectory(javaCompilePath)) {
		throw new IllegalStateException("Can't create project output: " + javaCompilePath);
	    }

	    ctx.addJavaClassPath(javaCompilePath);
	}

	return true;
    }

    public boolean buildSource(final RepositoryBuildSourceContext ctx) throws Exception {

	final ProjectBuildSourceContext projectContext = new ProjectBuildSourceContext(this, ctx);

	final Path source = projectContext.source;
	if (!Files.isDirectory(source)) {
	    throw new IllegalStateException("source is not a folder, " + source);
	}

	final Path distro = projectContext.distro;
	Files.createDirectories(distro);
	if (!Files.isDirectory(distro)) {
	    throw new IllegalStateException("distro is not a folder, " + distro);
	}

	{
	    Files.copy(//
		    source.resolve("project.inf"), //
		    distro.resolve("project.inf"), //
		    StandardCopyOption.REPLACE_EXISTING);
	}

	final Path javaSourcePath = projectContext.source.resolve("java");
	if (Files.isDirectory(javaSourcePath)) {

	    final Path cached = projectContext.cached;
	    Files.createDirectories(cached);
	    if (!Files.isDirectory(cached)) {
		throw new IllegalStateException("cached is not a folder, " + cached);
	    }

	    ctx.addJavaCompileList(this.name);

	    ctx.addJavaSourcePath(javaSourcePath);

	    final Path javaCompilePath = projectContext.cached.resolve("java");
	    Files.createDirectories(javaCompilePath);
	    if (!Files.isDirectory(javaCompilePath)) {
		throw new IllegalStateException("Can't create project output: " + javaCompilePath);
	    }

	    ctx.addJavaClassPath(javaCompilePath);
	}

	return true;
    }

    void compileAllJavaSource(final MakeCompileJava javaCompiler) throws Exception {

	{
	    final Path source = javaCompiler.sourceRoot.resolve(this.repo.name).resolve(this.name).resolve("jars");
	    if (Files.isDirectory(source)) {
		final Path output = javaCompiler.outputRoot.resolve("cached").resolve(this.repo.name).resolve(this.name)
			.resolve("jars");
		try (DirectoryStream<Path> newDirectoryStream = Files.newDirectoryStream(source)) {
		    for (final Path path : newDirectoryStream) {
			final String name = path.getFileName().toString();
			if (!name.endsWith(".zip") && !name.endsWith(".jar")) {
			    continue;
			}
			if (!Files.isRegularFile(path)) {
			    continue;
			}
			final Path target = output.resolve(name);
			if (Files.isRegularFile(target) && Files.getLastModifiedTime(target).toMillis() >= Files
				.getLastModifiedTime(path).toMillis()) {
			    javaCompiler.log("JAR: newer, target: " + target);
			    System.err.print(".");
			    continue;
			}
			Files.createDirectories(target.getParent());
			Files.copy(path, target, StandardCopyOption.REPLACE_EXISTING);
			System.err.print("c");
		    }
		}
	    }
	}
	{
	    final Path target = javaCompiler.outputRoot.resolve("cached").resolve(this.repo.name).resolve(this.name)
		    .resolve("java");

	    final Path source;
	    if (javaCompiler.sourcesFromOutput) {
		source = target;
	    } else {
		source = javaCompiler.sourceRoot.resolve(this.repo.name).resolve(this.name).resolve("java");
	    }
	    if (Files.isDirectory(source)) {
		final List<File> fileNames = new ArrayList<>();
		this.iterateJavaFiles(fileNames, source, null, target);

		System.err.print("@");

		javaCompiler.compileBatch(//
			target, //
			Arrays.asList(source.toFile()), //
			fileNames);

		{
		    final Path distro = javaCompiler.outputRoot.resolve("distro").resolve(this.repo.name)
			    .resolve(this.name).resolve("java");

		    Utils.sync(javaCompiler.console, //
			    source == target ? Arrays.asList(target) : Arrays.asList(target, source), //
			    distro//
		    );
		}
	    }
	}
    }

    @Override
    public boolean equals(final Object obj) {
	if (this == obj) {
	    return true;
	}
	if (obj == null) {
	    return false;
	}
	if (this.getClass() != obj.getClass()) {
	    return false;
	}
	final Project other = (Project) obj;
	if (this.name == null) {
	    if (other.name != null) {
		return false;
	    }
	} else if (!this.name.equals(other.name)) {
	    return false;
	}
	if (this.repo == null) {
	    if (other.repo != null) {
		return false;
	    }
	} else if (!this.repo.equals(other.repo)) {
	    return false;
	}
	return true;
    }

    public List<Project> getBuildSequence(final OperationContext context) {
	final Map<String, Project> checked = new HashMap<>();
	final List<Project> sequence = new ArrayList<>();
	return this.buildCalculateSequence(context, sequence, checked);
    }

    public final String getFullName() {
	return this.repo.name + '/' + this.name;
    }

    public final String getName() {
	return this.name;
    }

    public OptionList getDeclares() {
	return this.lstDeclares;
    }

    public OptionList getAugments() {
	return this.lstAugments;
    }

    public OptionList getKeywords() {
	return this.lstKeywords;
    }

    public OptionList getProvides() {
	return this.lstProvides;
    }

    public OptionList getRequires() {
	return this.lstRequires;
    }

    @Override
    public int hashCode() {
	final int prime = 31;
	int result = 1;
	result = prime * result + (this.name == null ? 0 : this.name.hashCode());
	result = prime * result + (this.repo == null ? 0 : this.repo.hashCode());
	return result;
    }

    private void iterateJavaFiles(final List<File> files, final Path sourceRoot, final Path relativePath,
	    final Path target) throws Exception {
	final Path focus;
	if (relativePath == null) {
	    focus = sourceRoot;
	} else {
	    focus = sourceRoot.resolve(relativePath);
	}
	try (DirectoryStream<Path> directoryStream = Files.newDirectoryStream(focus)) {
	    System.err.print("*");
	    for (final Path path : directoryStream) {
		final File file = path.toFile();
		final String name = file.getName();
		if (name.startsWith(".") || name.equals("CVS")) {
		    continue;
		}
		if (file.isDirectory()) {
		    final Path newRelative;
		    if (relativePath == null) {
			newRelative = path.getFileName();
		    } else {
			newRelative = relativePath.resolve(name);
		    }
		    this.iterateJavaFiles(files, sourceRoot, newRelative, target);
		    continue;
		}
		if (!name.endsWith(".java")) {
		    continue;
		}
		if (target != null) {
		    final Path checkClass = target.resolve(relativePath)
			    .resolve(name.substring(0, name.length() - 5) + ".class");
		    if (Files.isRegularFile(checkClass)) {
			if (Files.getLastModifiedTime(checkClass).toMillis() >= file.lastModified()) {
			    // same or newer output exists
			    continue;
			}
		    }
		}
		files.add(file);
	    }
	}
    }

    public void loadFromLocalIndex(final Repository repository, final Path projectRoot) throws Exception {
	final Path infoFile = projectRoot.resolve("project-index.env.inf");
	if (!Files.isRegularFile(infoFile)) {
	    throw new IllegalStateException("index not found, project: " + this.name + ", path=" + infoFile);
	}
	final Properties info = new Properties();
	try (BufferedReader newBufferedReader = Files.newBufferedReader(infoFile)) {
	    info.load(newBufferedReader);
	}

	final String name = info.getProperty("PROJ", "");
	if (!this.name.equals(name)) {
	    throw new IllegalStateException(
		    "name from index does not match, project: " + this.name + ", path=" + infoFile);
	}
	this.loadFromLocalIndex(repository, info);
    }

    public void loadFromLocalIndex(final Repository repository, final Properties info) {
	Project.updateList(info.getProperty("PRJ-DCL-" + this.name, "").split("\\s+"), this.lstDeclares);
	Project.updateList(info.getProperty("PRJ-KWD-" + this.name, "").split("\\s+"), this.lstKeywords);
	Project.updateList(info.getProperty("PRJ-AUG-" + this.name, "").split("\\s+"), this.lstAugments);
	Project.updateList(info.getProperty("PRJ-PRV-" + this.name, "").split("\\s+"), this.lstProvides);
	Project.updateList(info.getProperty("PRJ-REQ-" + this.name, "").split("\\s+"), this.lstRequires);
	Project.updateList(info.getProperty("PRJ-GET-" + this.name, "").split("\\s+"), this.lstContains);

	for (final OptionListItem declares : this.lstDeclares) {
	    this.repo.addDeclares(this, declares);
	    this.repo.distro.addDeclares(this, declares);
	}

	for (final OptionListItem keywords : this.lstKeywords) {
	    this.repo.addKeywords(this, keywords);
	    this.repo.distro.addKeywords(this, keywords);
	}

	for (final OptionListItem augments : this.lstAugments) {
	    this.repo.addAugments(this, augments);
	    this.repo.distro.addAugments(this, augments);
	}

	for (final OptionListItem provides : this.lstProvides) {
	    this.repo.addProvides(this, provides);
	    this.repo.distro.addProvides(this, provides);
	}
    }

    public void loadFromLocalSource(final ConsoleOutput console, final Repository repository, final Path projectRoot)
	    throws Exception {

	for (final OptionListItem declares : this.lstDeclares) {
	    this.repo.addDeclares(this, declares);
	    this.repo.distro.addDeclares(this, declares);
	}

	for (final OptionListItem keywords : this.lstKeywords) {
	    this.repo.addKeywords(this, keywords);
	    this.repo.distro.addKeywords(this, keywords);
	}

	for (final OptionListItem provides : this.lstProvides) {
	    this.repo.addProvides(this, provides);
	    this.repo.distro.addProvides(this, provides);
	}

	{
	    final Path source = projectRoot.resolve("jars");
	    if (Files.isDirectory(source)) {
		try (DirectoryStream<Path> newDirectoryStream = Files.newDirectoryStream(source)) {
		    for (final Path path : newDirectoryStream) {
			final String name = path.getFileName().toString();
			if (!name.endsWith(".zip") && !name.endsWith(".jar")) {
			    continue;
			}
			if (!Files.isRegularFile(path)) {
			    continue;
			}
			this.lstProvides.add(new OptionListItem("classpath.jars", "jars/" + name));
			this.lstContains.add("jars/" + name);
			console.outProgress('l');
		    }
		}
	    }
	}
	{
	    final Path source = projectRoot.resolve("data");
	    if (Files.isDirectory(source)) {
		this.lstProvides.add(new OptionListItem("project-data", "data.tbz"));
		this.lstContains.add("data.tbz");
		console.outProgress('l');
	    }
	}
	{
	    final Path source = projectRoot.resolve("docs");
	    if (Files.isDirectory(source)) {
		this.lstProvides.add(new OptionListItem("project-docs", "docs.tbz"));
		this.lstContains.add("docs.tbz");
		console.outProgress('l');
	    }
	}
	{
	    final Path source = projectRoot.resolve("java");
	    if (Files.isDirectory(source)) {
		this.lstProvides.add(new OptionListItem("classpath.jars", "java.jar"));
		this.lstContains.add("java.jar");
		console.outProgress('l');
	    }
	}
    }

    @Override
    public String toString() {
	return this.repo.name + "/" + this.name;
    }
}
