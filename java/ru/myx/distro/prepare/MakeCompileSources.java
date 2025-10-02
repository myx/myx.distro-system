package ru.myx.distro.prepare;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import ru.myx.distro.AbstractCommand;
import ru.myx.distro.AbstractDistroCommand;
import ru.myx.distro.OperationContext;
import ru.myx.distro.OperationObject;

public class MakeCompileSources extends AbstractDistroCommand {

    protected static final Map<String, OperationObject<? super MakeCompileSources>> OPERATIONS;

    static {
	OPERATIONS = new HashMap<>();
	MakeCompileSources.OPERATIONS.putAll(AbstractDistroCommand.OPERATIONS);

	final Map<String, OperationObject<MakeCompileSources>> operations = new HashMap<>();
	AbstractCommand.registerOperation(operations, context -> {
	    context.classesFromOutput = true;
	    return true;
	}, "--from-output");
	AbstractCommand.registerOperation(operations, context -> {
	    context.doImportFromIndex(context.outputRoot.normalize());
	    context.classesFromOutput = true;
	    return true;
	}, "--import-from-output");
	AbstractCommand.registerOperation(operations, context -> {
	    context.doAddAllSourceRepositories(context.sourceRoot.normalize());
	    return true;
	}, "--import-from-source");
	AbstractCommand.registerOperation(operations, context -> {
	    final MakeCompileJava javaCompiler = new MakeCompileJava(//
		    context.sourceRoot.normalize(), //
		    context.outputRoot.normalize()//
	    );
	    javaCompiler.sourcesFromOutput = context.classesFromOutput;
	    javaCompiler.console = context.console;
	    context.repositories.compileAllJavaSource(javaCompiler);
	    return true;
	}, "--all");
	AbstractCommand.registerOperation(operations, context -> {
	    if (!context.arguments.hasNext()) {
		throw new IllegalArgumentException("repository name is expected");
	    }

	    final String repositoryName = context.arguments.next();

	    final MakeCompileJava javaCompiler = new MakeCompileJava(//
		    context.sourceRoot.normalize(), //
		    context.outputRoot.normalize()//
	    );
	    javaCompiler.sourcesFromOutput = context.classesFromOutput;
	    javaCompiler.console = context.console;
	    final Repository repo = context.repositories.getRepository(repositoryName);
	    if (repo == null) {
		throw new IllegalArgumentException("repository is unknown, name: " + repositoryName);
	    }
	    repo.compileAllJavaSource(javaCompiler);

	    return true;
	}, "--repository");
	AbstractCommand.registerOperation(operations, context -> {
	    if (!context.arguments.hasNext()) {
		throw new IllegalArgumentException("project name is expected");
	    }

	    final String projectName = context.arguments.next();

	    context.doSelectProject(projectName);
	    context.doSelectRequired();

	    final MakeCompileJava javaCompiler = new MakeCompileJava(//
		    context.sourceRoot.normalize(), //
		    context.outputRoot.normalize()//
	    );
	    javaCompiler.sourcesFromOutput = context.classesFromOutput;
	    javaCompiler.console = context.console;
	    final Project proj = context.repositories.getProject(projectName);
	    if (proj == null) {
		throw new IllegalArgumentException("project is unknown, name: " + projectName);
	    }
	    proj.compileAllJavaSource(javaCompiler);

	    return true;
	}, "--project");

	MakeCompileSources.OPERATIONS.putAll(operations);
    }

    public static void main(final String[] args) throws Throwable {
	final MakeCompileSources context = new MakeCompileSources();
	context.console = new ConsoleOutput();
	context.repositories = new Distro();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, MakeCompileSources.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    @Override
    public boolean execute(final OperationContext context) throws Exception {
	if (!context.arguments.hasNext()) {
	    return false;
	}
	for (;;) {
	    final String command = context.arguments.next();
	    final OperationObject<? super MakeCompileSources> operation = MakeCompileSources.OPERATIONS.get(command);
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

    protected boolean classesFromOutput = false;

}
