package ru.myx.distro;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import ru.myx.distro.prepare.ConsoleOutput;
import ru.myx.distro.prepare.Distro;
import ru.myx.distro.prepare.OptionListItem;
import ru.myx.distro.prepare.Project;
import ru.myx.distro.prepare.Repository;

public class DistroSourceCommand extends AbstractDistroCommand {

    protected static final Map<String, OperationObject<? super DistroSourceCommand>> OPERATIONS;

    static {
	OPERATIONS = new HashMap<>();
	DistroSourceCommand.OPERATIONS.putAll(AbstractDistroCommand.OPERATIONS);

	final Map<String, OperationObject<DistroSourceCommand>> operations = new HashMap<>();
	{
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("path is expected for --repository agrument");
		}
		final String spec = context.arguments.next();
		final int pos = spec.indexOf('|');
		if (pos == -1) {
		    (new Repository(spec, null, context.repositories)).getClass();
		} else {
		    (new Repository(spec.substring(0, pos), spec.substring(pos + 1), context.repositories)).getClass();
		}
		return true;
	    }, "--repository");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doAddAllSourceRepositories(context.sourceRoot.normalize());
		return true;
	    }, "--import-from-source");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		if (context.outputRoot == null) {
		    throw new IllegalStateException("output is not set");
		}
		{
		    if (!context.arguments.hasNext()) {
			throw new IllegalArgumentException(
				"--clean-output requires an extra angument with output path");
		    }
		    final Path check = Paths.get(context.arguments.next());
		    if (!Files.isSameFile(check, context.outputRoot)) {
			throw new IllegalArgumentException(
				"--clean-output extra angument with output path should point to same location as the actual output setting (see --print-output-root and --output-root options)");
		    }
		}
		context.console.outInfo("cleaning: " + context.outputRoot);
		Utils.clearFolderContents(context.console, context.outputRoot);
		return true;
	    }, "--clean-output");
	}

	{

	    AbstractCommand.registerOperation(operations, context -> {
		context.doSelectAllFromSource();
		context.repositories.buildCalculateSequence(context, null);
		return true;
	    }, "--select-all-from-source");
	}

	{

	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepareBuildRoots();
		return true;
	    }, "--prepare-build-roots");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepareSourceToCachedIndex();
		return true;
	    }, "--prepare-source-to-cached-index");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepareBuildCompileIndex();
		return true;
	    }, "--prepare-build-compile-index");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepareBuildDistroIndex();
		return true;
	    }, "--prepare-build-distro-index");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepateBuildFetchMissing();
		return true;
	    }, "--prepare-build-fetch-missing");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepateBuildCompileJava();
		return true;
	    }, "--prepare-build-compile-java");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepareBuild();
		return true;
	    }, "--prepare-build");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("project name is expected");
		}

		context.doSelectProject(context.arguments.next());
		context.doSelectRequired();
		return context.build();
	    }, "--build-project");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("repository name is expected");
		}

		context.doSelectRepository(context.arguments.next());
		context.doSelectRequired();
		return context.build();
	    }, "--build-repository");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doSelectAll();
		return context.build();
	    }, "--build-all");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.doPrepareBuild();
		context.doSelectAllFromSource();
		context.build();
		return true;
	    }, "--build-distro-from-sources");

	    AbstractCommand.registerOperation(operations, context -> {
		context.doMakePackagesFromFolders();
		return true;
	    }, "--make-packages-from-folders");

	    AbstractCommand.registerOperation(operations, context -> {
		context.build();
		return true;
	    }, "--build");
	}

	DistroSourceCommand.OPERATIONS.putAll(operations);
    }

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final DistroSourceCommand context = new DistroSourceCommand();
	context.console = new ConsoleOutput();
	context.repositories = new Distro();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, DistroSourceCommand.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    protected DistroSourceCommand() {
	//
    }

    private boolean build() throws Exception {

	if (this.buildQueue.isEmpty()) {
	    throw new IllegalStateException("No queue to build");
	}
	try {
	    this.doMakePackagesFromFolders();
	    this.doSyncDistroFromCached();
	    return true;
	} finally {
	    this.buildQueue.clear();
	}
    }

    public void doMakePackagesFromFolders() throws Exception {

	final Project project = this.repositories.getProject("myx/myx.distro-deploy");
	if (project == null) {
	    throw new IllegalStateException("Need myx.distro-deploy project available!");
	}

	this.doRunJavaFromProject(project, "ru.myx.distro.MakePackagesFromFolders", new ArrayList<>());
    }

    public void doPrepareBuild() throws Exception {
	this.console.outDebug("prepare 'cache' build from 'source' directory");

	this.repositories.buildCalculateSequence(this, null);

	this.doPrepareBuildRoots();
	this.doPrepareBuildDistroIndex();
	this.doPrepareSourceToCachedIndex();
	this.doPrepateBuildFetchMissing();
	this.doPrepareBuildCompileIndex();
	this.doPrepateBuildCompileJava();
    }

    private void doPrepareBuildDistroIndex() throws Exception {
	this.repositories.buildPrepareDistroIndex(//
		this, //
		this.outputRoot.resolve("distro").normalize(), //
		true, //
		true //
	);
    }

    public void doPrepareBuildRoots() throws IOException {
	if (this.outputRoot == null) {
	    throw new IllegalStateException("outputRoot is not set, use --output-root option");
	}
	if (this.cachedRoot == null) {
	    throw new IllegalStateException("cachedRoot is not set, use --output-root or --cached-root option");
	}

	this.console.outDebug("check create build root directories, outputRoot: ", this.outputRoot);

	final Path distro = this.outputRoot.resolve("distro").normalize();
	final Path cached = this.cachedRoot.normalize();

	Files.createDirectories(distro);
	if (!Files.isDirectory(distro)) {
	    throw new IllegalStateException("distro is not a folder, " + distro);
	}
	Files.createDirectories(cached);
	if (!Files.isDirectory(cached)) {
	    throw new IllegalStateException("cached is not a folder, " + cached);
	}
    }

    public void doPrepareSourceToCachedIndex() throws Exception {
	this.console.outDebug("check update build source-2-cache indices");

	this.repositories.buildPrepareDistroIndex(//
		this, //
		this.cachedRoot.normalize(), //
		true, //
		false //
	);
    }

    public void doPrepareBuildCompileIndex() throws Exception {
	this.console.outDebug("check update build cache indices");

	this.repositories.buildPrepareCompileIndex(//
		this, //
		this.cachedRoot.normalize()//
	);
    }

    public void doPrepateBuildCompileJava() throws Exception {
	this.console.outDebug("check compile updated or missing java class files");

	final Set<Project> providers = this.repositories
		.getProvides(new OptionListItem("source-process", "compile-java"));

	this.console.outWarn("SKIPPED, providers, compile-java: " + providers);
    }

    public void doPrepateBuildFetchMissing() throws Exception {
	this.console.outDebug("check acquire missing classpath files for compile");

	final Set<Project> providers = this.repositories
		.getProvides(new OptionListItem("", "build.java-jar", "build.copy-jars"));

	this.console.outWarn("SKIPPED, providers, fetch-missing: " + providers);
    }

    public void doSelectAllFromSource() {
	this.console.outDebug("select all projects imported from source folder");

	for (final Project project : this.repositories.getSequenceProjects()) {
	    if (project.projectSourceRoot != null) {
		if (!this.buildQueue.contains(project)) {
		    this.buildQueue.add(project);
		}
	    }
	}
    }

    @Override
    public boolean execute(final OperationContext context) throws Exception {
	if (!context.arguments.hasNext()) {
	    return false;
	}
	for (;;) {
	    final String command = context.arguments.next();
	    final OperationObject<? super DistroSourceCommand> operation = DistroSourceCommand.OPERATIONS.get(command);
	    if (operation == null) {
		throw new IllegalArgumentException("Unknown option: " + command);
	    }
	    if (!operation.execute(this)) {
		this.console.outDebug("operation signalled a stop, exiting with: okState=",
			String.valueOf(this.okState));
		return this.okState;
	    }
	    if (!context.arguments.hasNext()) {
		return true;
	    }
	}
    }
}
