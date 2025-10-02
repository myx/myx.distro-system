package ru.myx.distro;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

import ru.myx.distro.prepare.ConsoleOutput;

public abstract class AbstractCommand extends OperationContext implements OperationObject<OperationContext> {
    protected static final Map<String, OperationObject<? super AbstractCommand>> OPERATIONS;
    static {
	OPERATIONS = new HashMap<>();

	final Map<String, OperationObject<AbstractCommand>> operations = new HashMap<>();

	{
	    AbstractCommand.registerOperation(operations, context -> {
		AbstractCommand.doPrintSyntax(context, operations);
		return true;
	    }, "--help", "--print-syntax");

	    AbstractCommand.registerOperation(operations, context -> {
		context.console.setSilent(false);
		context.console.setVerbose(true);
		context.console.setDebug(false);
		return true;
	    }, "--verbose", "-v");

	    AbstractCommand.registerOperation(operations, context -> {
		context.console.setSilent(false);
		context.console.setVerbose(true);
		context.console.setDebug(true);
		return true;
	    }, "--debug", "-vv");

	    AbstractCommand.registerOperation(operations, context -> {
		context.console.setSilent(true);
		context.console.setVerbose(false);
		context.console.setDebug(false);
		return true;
	    }, "--quiet", "--silent", "-q");

	    AbstractCommand.registerOperation(operations, context -> {
		context.noFail = true;
		return true;
	    }, "--no-fail");

	    AbstractCommand.registerOperation(operations, context -> {
		final String[] errors = context.console.clearCollectedErrors();
		if (errors != null && errors.length > 0) {
		    context.console.outWarn( //
			    "There were errors, exiting with error code, errors:\n" + String.join("\n", errors) //
		    );
		    context.okState = false;
		    return false;
		}
		return true;
	    }, "--fail-if-errors");

	    AbstractCommand.registerOperation(operations, context -> {
		final String[] errors = context.console.clearCollectedErrors();
		if (errors != null && errors.length > 0) {
		    context.console.outWarn( //
			    "There were errors:\n" + String.join("\n", errors) //
		    );
		}
		return true;
	    }, "--print-if-errors");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("text is expected for -p/--print agrument");
		}
		context.console.out(context.arguments.next());
		return true;
	    }, "--print", "-p");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("text is expected for -w/--warn agrument");
		}
		context.console.outWarn(context.arguments.next());
		return true;
	    }, "--warn", "-w");

	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("text is expected for -i/--info agrument");
		}
		context.console.outInfo(context.arguments.next());
		return true;
	    }, "--info", "-i");

	    AbstractCommand.registerOperation(operations, context -> {
		context.okState = true;
		return false;
	    }, "--done", "-T");

	    AbstractCommand.registerOperation(operations, context -> {
		context.okState = false;
		return false;
	    }, "--fail", "-F");
	}

	{
	    AbstractCommand.registerOperation(operations, context -> {
		final FolderSyncCommand sync = new FolderSyncCommand();
		sync.console = context.console;
		sync.arguments = context.arguments;
		return sync.execute(context);
	    }, "--exec-sync");
	}

	AbstractCommand.OPERATIONS.putAll(operations);
    }

    protected static void doPrintSyntax(final OperationContext context,
	    final Map<String, ? extends OperationObject<?>> operations) {
	System.err.println(context.getClass().getSimpleName() + ": command options:");
	final Map<String, Set<String>> commandsByName = new TreeMap<>();
	final Map<OperationObject<?>, Set<String>> commandsByCommand = new HashMap<>();

	for (final String key : new TreeSet<>(operations.keySet())) {
	    final OperationObject<?> operation = operations.get(key);
	    Set<String> commands = commandsByCommand.get(operation);
	    if (commands == null) {
		commands = new TreeSet<>();
		commandsByCommand.put(operation, commands);
		commandsByName.put(key, commands);
	    }
	    commands.add(key);
	}

	for (final String key : commandsByName.keySet()) {
	    System.err.println("\t" + commandsByName.get(key));
	}
    }

    public static <T extends OperationContext> void registerOperation(final Map<String, OperationObject<T>> operations,
	    final OperationObject<T> op, final String... keys) {
	for (final String key : keys) {
	    operations.put(key, op);
	}
    }

    protected AbstractCommand() {
	this.console = new ConsoleOutput();
    }

    protected AbstractCommand(final ConsoleOutput console) {
	this.console = console;
    }

    protected void deriveFrom(final AbstractCommand command) {
	this.console = command.console;
	this.arguments = command.arguments;
    }

    protected void doReset() {
	this.okState = true;
    }
}
