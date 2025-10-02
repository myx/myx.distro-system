package ru.myx.distro;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import ru.myx.distro.prepare.ConsoleOutput;
import ru.myx.distro.prepare.Distro;
import ru.myx.distro.prepare.Project;
import ru.myx.distro.prepare.Repository;

public class DistroImageCommand extends AbstractDistroCommand {

    protected static final Map<String, OperationObject<? super DistroImageCommand>> OPERATIONS;

    static {
	OPERATIONS = new HashMap<>();
	DistroImageCommand.OPERATIONS.putAll(AbstractDistroCommand.OPERATIONS);

	final Map<String, OperationObject<DistroImageCommand>> operations = new HashMap<>();
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
		DistroImageCommand.prepareCheckBuildRoots(context.outputRoot);
		return true;
	    }, "--prepare-build-roots");

	    AbstractCommand.registerOperation(operations, context -> {
		context.repositories.buildPrepareCompileIndex(//
			context, //
			context.outputRoot.resolve("cached").normalize()//
		);
		return true;
	    }, "--prepare-build-compile-index");

	    AbstractCommand.registerOperation(operations, context -> {
		context.repositories.buildPrepareDistroIndex(//
			context, //
			context.outputRoot.resolve("distro").normalize(), //
			true, //
			false //
		);
		return true;
	    }, "--prepare-build-distro-index");

	    AbstractCommand.registerOperation(operations, context -> {
		context.repositories.buildCalculateSequence(context, context.buildQueue);

		DistroImageCommand.prepareCheckBuildRoots(context.outputRoot);

		context.repositories.buildPrepareDistroIndex(//
			context, //
			context.outputRoot.resolve("distro").normalize(), //
			true, //
			true //
		);
		context.repositories.buildPrepareCompileIndex(//
			context, //
			context.cachedRoot.normalize()//
		);
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
		context.repositories.buildCalculateSequence(context, null);
		context.doSelectAll();
		return context.build();
	    }, "--build-all");
	}
	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.build();
		return true;
	    }, "--build");
	}

	DistroImageCommand.OPERATIONS.putAll(operations);
    }

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final DistroImageCommand context = new DistroImageCommand();
	context.console = new ConsoleOutput();
	context.repositories = new Distro();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, DistroImageCommand.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    static void prepareCheckBuildRoots(final Path outputRoot) throws IOException {
	final Path distro = outputRoot.resolve("distro").normalize();
	final Path cached = outputRoot.resolve("cached").normalize();

	Files.createDirectories(distro);
	if (!Files.isDirectory(distro)) {
	    throw new IllegalStateException("distro is not a folder, " + distro);
	}
	Files.createDirectories(cached);
	if (!Files.isDirectory(cached)) {
	    throw new IllegalStateException("cached is not a folder, " + cached);
	}
    }

    protected DistroImageCommand() {
	//
    }

    private boolean build() {
	if (this.buildQueue.isEmpty()) {
	    throw new IllegalStateException("No queue to build");
	}
	try {
	    final boolean result = true;
	    for (;;) {
		final Project project = this.buildQueue.pollFirst();
		if (project == null) {
		    break;
		}
		this.console.outProgressLine("BUILD: project: " + project);
	    }
	    return result;
	} finally {
	    this.buildQueue.clear();
	}
    }

    @Override
    public boolean execute(final OperationContext context) throws Exception {
	if (!context.arguments.hasNext()) {
	    return false;
	}
	for (;;) {
	    final String command = context.arguments.next();
	    final OperationObject<? super DistroImageCommand> operation = DistroImageCommand.OPERATIONS.get(command);
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
