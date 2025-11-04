package ru.myx.distro;

import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

import ru.myx.distro.prepare.Distro;
import ru.myx.distro.prepare.OptionList;
import ru.myx.distro.prepare.OptionListItem;
import ru.myx.distro.prepare.Project;
import ru.myx.distro.prepare.Repository;

public abstract class AbstractDistroCommand extends AbstractRepositoryCommand {

    protected static final Map<String, OperationObject<? super AbstractDistroCommand>> OPERATIONS;

    static {
	OPERATIONS = new HashMap<>();
	AbstractDistroCommand.OPERATIONS.putAll(AbstractRepositoryCommand.OPERATIONS);

	final Map<String, OperationObject<AbstractDistroCommand>> operations = new HashMap<>();
	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.doReset();
		return true;
	    }, "--reset");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("path is expected for --source-root agrument");
		}
		context.sourceRoot = Paths.get(context.arguments.next());
		return true;
	    }, "--source-root");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("path is expected for --output-root agrument");
		}
		context.outputRoot = Paths.get(context.arguments.next());
		if (context.cachedRoot == null) {
		    context.cachedRoot = context.outputRoot.resolve("cached");
		}
		return true;
	    }, "--output-root");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("path is expected for --output-root agrument");
		}
		context.cachedRoot = Paths.get(context.arguments.next());
		return true;
	    }, "--cached-root");

	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.sourceRoot == null ? "" : context.sourceRoot);
		return true;
	    }, "--print-source-root");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.outputRoot == null ? "" : context.outputRoot);
		return true;
	    }, "--print-output-root");
	}

	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.doImportFromIndex(context.cachedRoot.normalize());
		return true;
	    }, "--import-from-cached");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doImportFromIndex(context.outputRoot.resolve("distro").normalize());
		return true;
	    }, "--import-from-distro");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("directory path is expected");
		}
		context.doImportFromIndex(Paths.get(context.arguments.next()).normalize());
		return true;
	    }, "--import-from-index");
	}

	{
	    AbstractCommand.registerOperation(operations, context -> {
		return context.repositories.buildCalculateSequence(context, null);
	    }, "--prepare-full-sequence");

	    AbstractCommand.registerOperation(operations, context -> {
		return context.repositories.buildCalculateSequence(context, context.buildQueue);
	    }, "--prepare-sequence");

	    AbstractCommand.registerOperation(operations, context -> {
		for (final Project project : context.repositories.getSequenceProjects()) {
		    System.out.println(project.getFullName());
		}
		return true;
	    }, "--print-full-sequence");

	    AbstractCommand.registerOperation(operations, context -> {

		for (final Project project : context.buildQueue) {
		    System.out.println(project.getFullName());
		}
		return true;
	    }, "--print-sequence");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem require : project.getRequires()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			builder.append(projectName).append(' ').append(require.toString());
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-requires");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem provide : project.getProvides()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			builder.append(projectName).append(' ').append(provide.toString());
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-provides");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem provide : project.getProvides()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			final List<String> items = new ArrayList<>();
			provide.fillList(projectName + ' ', items);
			builder.append(String.join("\n", items));
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-provides-separate-lines");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		Map<String, Project> projects = context.repositories.getProjects();
		boolean first = true;
		for (final Project project : projects.values()) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem provide : project.getProvides()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			final List<String> items = new ArrayList<>();
			provide.fillList(projectName + ' ', items);
			builder.append(String.join("\n", items));
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-all-provides-separate-lines");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem require : project.getDeclares()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			builder.append(projectName).append(' ').append(require.toString());
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-declares");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem provide : project.getDeclares()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			final List<String> items = new ArrayList<>();
			provide.fillList(projectName + ' ', items);
			builder.append(String.join("\n", items));
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-declares-separate-lines");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		Map<String, Project> projects = context.repositories.getProjects();
		boolean first = true;
		for (final Project project : projects.values()) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem provide : project.getDeclares()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			final List<String> items = new ArrayList<>();
			provide.fillList(projectName + ' ', items);
			builder.append(String.join("\n", items));
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-all-declares-separate-lines");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem require : project.getKeywords()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			builder.append(projectName).append(' ').append(require.toString());
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-keywords");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem provide : project.getKeywords()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			final List<String> items = new ArrayList<>();
			provide.fillList(projectName + ' ', items);
			builder.append(String.join("\n", items));
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-keywords-separate-lines");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		Map<String, Project> projects = context.repositories.getProjects();
		boolean first = true;
		for (final Project project : projects.values()) {
		    final String projectName = project.getFullName();
		    for (final OptionListItem provide : project.getKeywords()) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			final List<String> items = new ArrayList<>();
			provide.fillList(projectName + ' ', items);
			builder.append(String.join("\n", items));
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-all-keywords-separate-lines");

	    AbstractCommand.registerOperation(operations, context -> {
		final StringBuilder builder = new StringBuilder(256);
		boolean first = true;
		for (final Project project : context.buildQueue) {
		    final String projectName = project.getFullName();
		    for (final Project sequenceProject : project.getBuildSequence(context)) {
			if (first) {
			    first = false;
			} else {
			    builder.append('\n');
			}
			builder.append(projectName).append(' ').append(sequenceProject.getFullName());
		    }
		}
		System.out.println(builder);
		return true;
	    }, "--print-sequence-separate-lines");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("name is expected for --print-repo-provides argument");
		}
		final String repositoryName = context.arguments.next();
		final Repository repository = context.repositories.getRepository(repositoryName);
		if (repository == null) {
		    throw new IllegalArgumentException("repository in unknown, name: " + repositoryName);
		}
		final Map<String, Set<Project>> provides = repository.getProvides();
		final StringBuilder builder = new StringBuilder(256);
		for (final String provide : provides.keySet()) {
		    for (final Project project : provides.get(provide)) {
			System.out.println(builder//
				.append(project.repo.name).append('/').append(project.name)//
				.append(' ')//
				.append(provide)//
			);
			builder.setLength(0);
		    }
		}
		return true;
	    }, "--print-repo-provides");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("name is expected for --print-repo-provides argument");
		}
		final String repositoryName = context.arguments.next();
		final Repository repository = context.repositories.getRepository(repositoryName);
		if (repository == null) {
		    throw new IllegalArgumentException("repository in unknown, name: " + repositoryName);
		}
		final Map<String, Set<Project>> provides = repository.getProvides();
		final StringBuilder builder = new StringBuilder(256);
		for (final String provide : provides.keySet()) {
		    builder.append(provide).append('=');
		    for (final Project project : provides.get(provide)) {
			builder.append(project.repo.name).append('/').append(project.name).append(':');
		    }
		    System.out.println(builder);
		    builder.setLength(0);
		}
		return true;
	    }, "--print-repo-provide-index");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException(
			    "projectName is expected for --print-project-build-classpath argument");
		}
		final String projectName = context.arguments.next();
		final Project project = context.repositories.getProject(projectName);
		if (project == null) {
		    throw new IllegalArgumentException("project is unknown, name: " + projectName);
		}

		final ClasspathBuilder classpath = new ClasspathBuilder();
		context.doMakeFillProjectRuntimeClasspath(project, classpath);

		for (final String path : classpath) {
		    System.out.println(path);
		}

		return true;
	    }, "--print-project-build-classpath");
	}

	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.repositories.buildCalculateSequence(context, null);
		context.doSelectAll();
		return true;
	    }, "--select-all");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("project name is expected");
		}
		context.doSelectProject(context.arguments.next());
		return true;
	    }, "--select-project");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("provider spec is expected");
		}
		context.doSelectProviders(new OptionListItem(context.arguments.next()));
		return true;
	    }, "--select-providers");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("repository name is expected");
		}
		context.doSelectRepository(context.arguments.next());
		return true;
	    }, "--select-repository");

	    AbstractCommand.registerOperation(operations, context -> {
		if (context.buildQueue.isEmpty()) {
		    throw new IllegalStateException("No queue to build");
		}
		context.doSelectRequired();
		return true;
	    }, "--select-required");

	    AbstractCommand.registerOperation(operations, context -> {
		if (context.buildQueue.isEmpty()) {
		    throw new IllegalStateException("No queue to build");
		}
		context.doSelectAffected();
		return true;
	    }, "--select-affected");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("project name is expected");
		}
		context.doUnselectProject(context.arguments.next());
		return true;
	    }, "--unselect-project");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("project name is expected");
		}
		context.doUnselectProviders(new OptionListItem(context.arguments.next()));
		return true;
	    }, "--unselect-providers");

	    AbstractCommand.registerOperation(operations, context -> {
		for (final Project project : context.buildQueue) {
		    System.out.println(project.repo.name + '/' + project.name);
		}
		return true;
	    }, "--print-selected");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.doSyncDistroFromCached();
		for (final Project project : context.buildQueue) {
		    System.out.println(project.repo.name + '/' + project.name);
		}
		return true;
	    }, "--sync-distro-from-cached");
	}

	{

	    {
		AbstractCommand.registerOperation(operations, context -> {
		    if (!context.arguments.hasNext()) {
			throw new IllegalArgumentException(
				"projectName is expected for --run-java-from-project agrument");
		    }
		    final String projectName = context.arguments.next().trim();

		    if (!context.arguments.hasNext()) {
			throw new IllegalArgumentException(
				"className is expected for --run-java-from-project agrument");
		    }
		    final String className = context.arguments.next().trim();

		    final Project project = context.repositories.getProject(projectName);
		    if (project == null) {
			throw new IllegalArgumentException("project is unknown: name: " + projectName);
		    }

		    final List<String> arguments = new ArrayList<>();
		    while (context.arguments.hasNext()) {
			final String argument = context.arguments.next().trim();
			if ("--done".equals(argument)) {
			    break;
			}
			arguments.add(argument);
		    }

		    return context.doRunJavaFromProject(project, className, arguments);
		}, "--run-java-from-project");
	    }
	}

	AbstractDistroCommand.OPERATIONS.putAll(operations);
    }
    protected QueueSelection buildQueue = new QueueSelection();

    public Path outputRoot = null;
    public Path sourceRoot = null;

    protected AbstractDistroCommand() {
	super();
    }

    protected AbstractDistroCommand(final Distro repositories) {
	super(repositories);
    }

    @Override
    protected void deriveFrom(final AbstractCommand command) {
	super.deriveFrom(command);
	if (command instanceof AbstractDistroCommand) {
	    this.outputRoot = ((AbstractDistroCommand) command).outputRoot;
	    this.sourceRoot = ((AbstractDistroCommand) command).sourceRoot;
	    this.buildQueue = ((AbstractDistroCommand) command).buildQueue;
	}
    }

    public void doImportFromIndex(final Path distroRoot) throws Exception {
	this.console.outDebug("importing repositories from index, path: ", distroRoot);

	if (!Files.isDirectory(distroRoot)) {
	    throw new IllegalArgumentException("distro: Path " + distroRoot + " does not exsist or not a directory!");
	}

	final List<String> repositoryNames = Files.readAllLines(distroRoot.resolve("distro-namespaces.txt"));

	for (final String repositoryName : repositoryNames) {
	    final Path repositoryRoot = distroRoot.resolve(repositoryName);
	    if (Repository.checkIfRepository(repositoryRoot)) {
		final Repository repository = Repository.staticLoadFromLocalIndex(this.repositories, repositoryRoot);
		if (repository != null) {
		    repository.loadFromLocalIndex(this.repositories, repositoryRoot);
		}
	    }
	}

    }

    public ClasspathBuilder doMakeFillProjectRuntimeClasspath(final Project project, final ClasspathBuilder classpath) {
	final Set<String> known = new TreeSet<>();
	final LinkedList<Project> queue = new LinkedList<>();

	queue.addLast(project);

	for (;;) {
	    final Project current = queue.pollFirst();
	    if (current == null) {
		return classpath;
	    }

	    this.console.outDebug(" CP-NEXT: ", current);

	    known.add(current.getName());
	    current.buildPrepareCompileIndexMakeClasspath(classpath);

	    for (final OptionListItem requires : current.getRequires()) {
		final Set<Project> providers = this.repositories.getProvides(requires);
		if (providers == null) {
		    if (this.noFail) {
			this.console.outError("ERROR: required item is unknown, name: " + requires);
			continue;
		    }
		    throw new IllegalArgumentException("required item is unknown, name: " + requires);
		}

		for (final Project provider : providers) {
		    this.console.outDebug(" PV-NEXT: ", provider, ", known: ", known);
		    if (known.add(provider.toString())) {
			queue.addFirst(provider);
		    }
		}
	    }
	}
    }

    @Override
    public void doReset() {
	super.doReset();
	this.buildQueue.clear();
    }

    public boolean doRunJavaFromProject(final Project project, final String className, final List<String> arguments)
	    throws Exception {

	final ClasspathBuilder classpath = this.doMakeFillProjectRuntimeClasspath(project, new ClasspathBuilder());

	final ArrayList<URL> urls = new ArrayList<>();
	for (final String item : classpath) {
	    /**
	     * <code>
	    if(item.startsWith("myx/myx.distro-source/")){
	    	continue;
	    }
	    </code>
	     */
	    if (item.contains("://")) {
		urls.add(new URL(item));
	    } else {
		urls.add(this.cachedRoot.resolve(item).toUri().toURL());
	    }
	}

	this.console.outDebug("project: ", project, ", className: ", className);
	this.console.outDebug("classPath: ", urls);
	this.console.outDebug("arguments: ", arguments);

	try (final URLClassLoader loader = new URLClassLoader(//
		"ProjectClassLoader[" + project + "]", //
		urls.toArray(new URL[urls.size()]), //
		this.getClass().getClassLoader()//
	)) {

	    final Class<?> cls = loader.loadClass(className);

	    if (AbstractCommand.class.isAssignableFrom(cls)) {
		this.console.outDebug("working with an AbstractCommand, class: ", cls.getName());
		final AbstractCommand command = (AbstractCommand) cls.getDeclaredConstructor().newInstance();
		command.deriveFrom(this);
		command.arguments = arguments.iterator();
		return command.execute(command);
	    }

	    {
		final OperationContext context = new OperationContext();
		context.console = this.console;
		context.arguments = arguments.iterator();

		throw new IllegalArgumentException("Don't know how to run, class: " + cls.getName());
	    }

	}
    }

    public void doSelectAll() {
	this.console.outDebug("select all projects");

	for (final Project project : this.repositories.getSequenceProjects()) {
	    if (!this.buildQueue.contains(project)) {
		this.buildQueue.add(project);
	    }
	}
    }

    public void doSelectProject(final String projectName) {
	this.console.outDebug("select project: ", projectName);

	final Project project = this.repositories.getProject(projectName);
	if (project == null) {
	    throw new IllegalArgumentException("project in unknown, project: " + projectName);
	}
	if (!this.buildQueue.contains(project)) {
	    this.buildQueue.add(project);
	}
    }

    public void doSelectProviders(final OptionListItem spec) {
	this.console.outDebug("select providers: ", spec);

	final Set<Project> providers = this.repositories.getProvides(spec);
	if (providers == null) {
	    if (this.noFail) {
		this.console.outError("ERROR: required item is unknown, name: " + spec);
		return;
	    }
	    throw new IllegalArgumentException("required item is unknown, name: " + spec);
	}

	final LinkedList<Project> queue = new LinkedList<>(this.buildQueue);
	final Set<String> known = new TreeSet<>();
	queue: for (;;) {
	    final Project project = queue.pollFirst();
	    if (project == null) {
		this.console.outDebug("SBQ-DONE");
		break queue;
	    }
	    this.console.outDebug("SBQ-KNOW");
	    known.add(project.getName());
	}

	for (final Project provider : providers) {
	    this.console.outDebug(" SPV-NEXT: ", provider);

	    if (known.add(provider.name)) {
		this.buildQueue.add(provider);
	    }
	}
    }

    public void doSelectRepository(final String repositoryName) {
	this.console.outDebug("select repository: ", repositoryName);

	final Repository repository = this.repositories.getRepository(repositoryName);
	if (repository == null) {
	    throw new IllegalArgumentException("repository name is unknown, name: " + repositoryName);
	}

	for (final Project project : repository.getProjects()) {
	    if (project.projectSourceRoot != null) {
		if (!this.buildQueue.contains(project)) {
		    this.buildQueue.add(project);
		}
	    }
	}
    }

    public void doSelectRequired() {
	this.console.outDebug("select required, queue: ", this.buildQueue);

	final LinkedList<Project> queue = new LinkedList<>(this.buildQueue);
	final Map<String, Project> seen = new TreeMap<>();
	final Map<String, Project> know = new TreeMap<>();

	this.buildQueue.clear();

	queue: for (;;) {
	    final Project project = queue.peekFirst();
	    if (project == null) {
		this.console.outDebug("BQ-DONE");
		break queue;
	    }

	    if (know.containsKey(project.getFullName())) {
		queue.removeFirst();
		continue queue;
	    }

	    for (final OptionListItem requires : project.getRequires()) {
		final Set<Project> providers = this.repositories.getProvides(requires);
		if (providers == null) {
		    if (this.noFail) {
			this.console.outError("ERROR: required item is unknown, name: " + requires);
			continue;
		    }
		    throw new IllegalArgumentException("required item is unknown, name: " + requires + ", "
			    + this.repositories.getProject(requires.getName()));
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
		this.buildQueue.add(project);
	    }

	    continue queue;
	}

    }

    public void doSelectAffected() {
	this.console.outDebug("select affected, queue: ", this.buildQueue);

	final LinkedList<Project> queue = new LinkedList<>(this.buildQueue);
	final Map<String, Project> seen = new TreeMap<>();
	final Map<String, Project> know = new TreeMap<>();

	this.buildQueue.clear();

	queue: for (;;) {
	    final Project project = queue.peekFirst();
	    if (project == null) {
		this.console.outDebug("BQ-DONE");
		break queue;
	    }

	    if (know.containsKey(project.getFullName())) {
		queue.removeFirst();
		continue queue;
	    }

	    final OptionList provides = project.getProvides();
	    if (provides == null) {
		throw new IllegalArgumentException(
			"provided items unknown, name: " + this.repositories.getProject(project.getName()));
	    }

	    check: for (final Project candidate : this.repositories.getProjects().values()) {
		if (know.containsKey(candidate.getFullName()) || candidate.projectSourceRoot == null) {
		    continue check;
		}

		for (final OptionListItem requires : candidate.getRequires()) {
		    for (final OptionListItem provide : provides) {
			if (provide.equals(requires) && seen.putIfAbsent(candidate.getFullName(), candidate) == null) {
			    queue.addLast(candidate);
			    continue queue;
			}
		    }
		}
	    }

	    if (know.putIfAbsent(project.getFullName(), project) == null) {
		this.buildQueue.add(project);
	    }

	    continue queue;
	}

    }

    public void doSyncDistroFromCached() throws Exception {

	final Path cachedRoot = this.cachedRoot;
	final Path distroRoot = this.outputRoot.resolve("distro");

	if (!Files.isDirectory(cachedRoot)) {
	    throw new IllegalStateException("'cached' directory does not exist: path: " + cachedRoot);
	}

	if (!Files.isDirectory(distroRoot)) {
	    throw new IllegalStateException("'distro' directory does not exist: path: " + distroRoot);
	}

	this.console.outDebug("synching cached-to-distro: distro: ", distroRoot);

	for (final Repository repository : this.repositories.getRepositories()) {
	    final String repositoryName = repository.getName();
	    final Path repositoryCached = cachedRoot.resolve(repositoryName);
	    final Path repositoryDistro = distroRoot.resolve(repositoryName);

	    for (final String fileName : new String[] { //
		    "repository.inf", "repository-index.env.inf", //
	    }) {

		final FileSyncCommand command = new FileSyncCommand(//
			FileSyncOption.DELETE_MISSNG, //
			FileSyncOption.KEEP_DATE);

		command.console = this.console;
		command.setSourceFile(repositoryCached.resolve(fileName));
		command.setTargetFile(repositoryDistro.resolve(fileName));

		command.doSync();
	    }

	    for (final Project project : repository.getProjects()) {
		final String projectName = project.getName();
		final Path projectCached = repositoryCached.resolve(projectName);
		final Path projectDistro = repositoryDistro.resolve(projectName);

		for (final String fileName : new String[] { //
			"project.inf", "project-index.env.inf", "data.tbz", "docs.tbz", "java.jar",//
		}) {

		    final FileSyncCommand command = new FileSyncCommand(//
			    FileSyncOption.DELETE_MISSNG, //
			    FileSyncOption.KEEP_DATE);

		    command.console = this.console;
		    command.setSourceFile(projectCached.resolve(fileName));
		    command.setTargetFile(projectDistro.resolve(fileName));

		    command.doSync();
		}
		for (final String folderName : new String[] { //
			"jars", "host", "image-process" }) {

		    final FolderSyncCommand command = new FolderSyncCommand(//
			    FolderSyncOption.DELETE_MISSNG, //
			    FolderSyncOption.IGNORE_HIDDEN, //
			    FolderSyncOption.KEEP_DATES //
		    );

		    command.console = this.console;
		    command.addSourceRoot(projectCached.resolve(folderName));
		    command.setTargetRoot(projectDistro.resolve(folderName));
		    command.addExcludeName("CVS");

		    command.doSync();
		}
	    }
	}
    }

    public void doUnselectProject(final String projectName) {
	this.console.outDebug("unselect project: ", projectName);

	final Project project = this.repositories.getProject(projectName);
	if (project == null) {
	    throw new IllegalArgumentException("project in unknown, project: " + projectName);
	}
	if (this.buildQueue.remove(project)) {
	    this.console.outDebug("project removed from the buildQueue: ", project);
	}
    }

    public void doUnselectProviders(final OptionListItem spec) {
	this.console.outDebug("unselect providers: ", spec);

	final Set<Project> providers = this.repositories.getProvides(spec);
	if (providers == null) {
	    if (this.noFail) {
		this.console.outError("ERROR: required item is unknown, name: " + spec);
		return;
	    }
	    throw new IllegalArgumentException("required item is unknown, name: " + spec);
	}

	for (final Project provider : providers) {
	    this.console.outDebug(" UPV-NEXT: ", provider);
	    if (this.buildQueue.remove(provider)) {
		this.console.outDebug("project removed from the buildQueue: ", provider);
	    }
	}
    }

}
