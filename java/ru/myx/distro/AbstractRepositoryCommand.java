package ru.myx.distro;

import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;

import ru.myx.distro.prepare.Distro;
import ru.myx.distro.prepare.OptionListItem;
import ru.myx.distro.prepare.Project;
import ru.myx.distro.prepare.Repository;

public abstract class AbstractRepositoryCommand extends AbstractCommand {
    protected static final Map<String, OperationObject<? super AbstractRepositoryCommand>> OPERATIONS;

    static {
	OPERATIONS = new HashMap<>();
	AbstractRepositoryCommand.OPERATIONS.putAll(AbstractCommand.OPERATIONS);

	final Map<String, OperationObject<AbstractRepositoryCommand>> operations = new HashMap<>();

	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.doReset();
		return true;
	    }, "--reset");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("path is expected for --cached-root agrument");
		}
		context.cachedRoot = Paths.get(context.arguments.next());
		return true;
	    }, "--cached-root");

	    AbstractCommand.registerOperation(operations, context -> {
		context.cachedRoot = Files.createTempDirectory("myx.distro-cached");
		context.console.outInfo("Temporary cacheRoot created: " + context.cachedRoot);
		return true;
	    }, "--temp-cached-root");

	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.cachedRoot == null ? "" : context.cachedRoot);
		return true;
	    }, "--print-cached-root");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException(
			    "repositorySpec is expected for --add-remote-repository agrument");
		}
		final String repositorySpec = context.arguments.next().trim();
		context.doAddRemoteRepository(repositorySpec);
		return true;
	    }, "--add-remote-repository");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException(
			    "repositoryPath is expected for --add-source-repository agrument");
		}
		final Path repositorySourceRoot = Paths.get(context.arguments.next());
		context.doAddSourceRepository(repositorySourceRoot);
		return true;
	    }, "--add-source-repository");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("path is expected for --add-all-source-repositories agrument");
		}
		final Path sourceRoot = Paths.get(context.arguments.next());
		context.doAddAllSourceRepositories(sourceRoot);
		return true;
	    }, "--add-all-source-repositories");

	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrintRepositories();
		return true;
	    }, "--print-repositories");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrintProjects();
		return true;
	    }, "--print-projects");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		if (context.cachedRoot == null) {
		    throw new IllegalStateException("cacheRoot is not set, use --cached-root option");
		}
		{
		    if (!context.arguments.hasNext()) {
			throw new IllegalArgumentException(
				"--clean-cached requires an extra angument with output path");
		    }
		    final Path check = Paths.get(context.arguments.next());
		    if (!Files.isSameFile(check, context.cachedRoot)) {
			throw new IllegalArgumentException(
				"--clean-cached extra argument with output path should point to same location as the actual output setting (see --print-output-root and --output-root options)");
		    }
		}
		context.console.outInfo("cleaning: " + context.cachedRoot);
		Utils.clearFolderContents(context.console, context.cachedRoot);
		return true;
	    }, "--clean-cached");
	}

	AbstractRepositoryCommand.OPERATIONS.putAll(operations);
    }

    public Distro repositories = null;

    public Path cachedRoot = null;

    protected AbstractRepositoryCommand() {
	this.repositories = new Distro();
    }

    protected AbstractRepositoryCommand(final Distro repositories) {
	this.repositories = repositories;
    }

    @Override
    protected void deriveFrom(final AbstractCommand command) {
	super.deriveFrom(command);
	if (command instanceof AbstractRepositoryCommand) {
	    this.repositories = ((AbstractRepositoryCommand) command).repositories;
	    this.cachedRoot = ((AbstractRepositoryCommand) command).cachedRoot;
	}
    }

    protected void doAddAllSourceRepositories(final Path sourceRoot) throws Exception {

	this.console.outDebug("adding all source repositories, sourceRoot: ", sourceRoot);

	this.console.outProgress("IS(");
	if (!Files.isDirectory(sourceRoot)) {
	    throw new IllegalArgumentException("sourceRoot " + sourceRoot + " does not exsist or not a directory!");
	}

	try (final DirectoryStream<Path> repositories = Files.newDirectoryStream(sourceRoot)) {
	    for (final Path repositorySourceRoot : repositories) {
		if (Repository.checkIfRepository(repositorySourceRoot)) {
		    this.console.outProgress("R(");

		    final Repository repository = Repository.staticLoadFromLocalSource(this.repositories,
			    repositorySourceRoot);
		    if (repository != null) {
			repository.loadFromLocalSource(this.console, this.repositories, repositorySourceRoot);
		    }

		    this.console.outProgress(")");
		    continue;
		}
	    }
	}

	this.console.outProgress(")");
    }

    protected void doAddRemoteRepository(final String repositorySpec) throws Exception {

	this.console.outDebug("adding remote repository, path: ", repositorySpec);

	final int pos = repositorySpec.indexOf('|');
	if (pos == -1) {
	    (new Repository(repositorySpec, null, this.repositories)).getClass();
	} else {
	    (new Repository(repositorySpec.substring(0, pos), repositorySpec.substring(pos + 1), this.repositories))
		    .getClass();
	}
    }

    protected void doAddSourceRepository(final Path repositorySourceRoot) throws Exception {

	this.console.outDebug("adding source repository, path: ", repositorySourceRoot);

	if (!Files.isDirectory(repositorySourceRoot)) {
	    throw new IllegalArgumentException(
		    "repositorySourceRoot " + repositorySourceRoot + " does not exsist or not a directory!");
	}

	this.console.outProgress("SR(");
	if (!Repository.checkIfRepository(repositorySourceRoot)) {
	    throw new IllegalArgumentException(
		    "repositorySourceRoot " + repositorySourceRoot + " is not a valid repository!");
	}

	final Repository repository = Repository.staticLoadFromLocalSource(this.repositories, repositorySourceRoot);
	if (repository != null) {
	    repository.loadFromLocalSource(this.console, this.repositories, repositorySourceRoot);
	}

	this.console.outProgress(")");
    }

    protected void doPrintProjects() {
	for (final Repository repository : this.repositories.getRepositories()) {
	    for (final Project project : repository.getProjects()) {
		this.console.out(repository.name + '/' + project.name);

		{
		    final StringBuilder builder = new StringBuilder();
		    for (final OptionListItem provide : project.getProvides()) {
			builder.append(" ").append(provide);
		    }
		    if (builder.length() > 0) {
			this.console.out("\tProvides:" + builder);
		    }
		}

		{
		    final StringBuilder builder = new StringBuilder();
		    for (final OptionListItem require : project.getRequires()) {
			builder.append(" ").append(require);
		    }
		    if (builder.length() > 0) {
			this.console.out("\tRequires:" + builder);
		    }
		}
	    }
	}
    }

    protected void doPrintRepositories() {
	for (final Repository repository : this.repositories.getRepositories()) {
	    this.console.out(repository.name);
	}
    }

    @Override
    protected void doReset() {
	this.console.outDebug("resetting cachedRoot & repositories");
	super.doReset();
	this.cachedRoot = null;
	this.repositories.reset();
    }
}
