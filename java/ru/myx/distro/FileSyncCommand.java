package ru.myx.distro;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.FileTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import ru.myx.distro.prepare.ConsoleOutput;

public class FileSyncCommand extends AbstractCommand {
    protected static final Map<String, OperationObject<? super FileSyncCommand>> OPERATIONS;
    static {
	OPERATIONS = new HashMap<>();
	FileSyncCommand.OPERATIONS.putAll(AbstractCommand.OPERATIONS);

	final Map<String, OperationObject<FileSyncCommand>> operations = new HashMap<>();

	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.reset();
		return true;
	    }, "--reset");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doDeleteMissing = true;
		return true;
	    }, "--delete-missing");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doOverwriteAll = true;
		return true;
	    }, "--overwrite-all");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doKeepDates = true;
		return true;
	    }, "--keep-dates");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doDryRun = true;
		return true;
	    }, "--dry-run");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("source expected after --source option");
		}
		context.setSourceFile(context.arguments.next());
		return true;
	    }, "--source");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("target expected after --target option");
		}
		context.setTargetFile(context.arguments.next().trim());
		return true;
	    }, "--target");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doSync();
		return true;
	    }, "--do-sync-continue-always");
	    AbstractCommand.registerOperation(operations, context -> {
		return context.doSync() > 0;
	    }, "--do-sync");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.updates);
		return true;
	    }, "--print-updates");
	}

	FileSyncCommand.OPERATIONS.putAll(operations);
    }

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final FileSyncCommand context = new FileSyncCommand();
	context.console = new ConsoleOutput();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, FileSyncCommand.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    private Path sourceFile = null;
    private Path targetFile = null;

    private boolean doOverwriteAll = false;
    private boolean doDeleteMissing = false;
    private boolean doKeepDates = false;
    private boolean doDryRun = false;

    int updates = 0;

    protected FileSyncCommand(final FileSyncOption... options) {
	if (options != null) {
	    this.setOptions(options);
	}
    }

    public int doSync() throws Exception {
	if (!Files.isRegularFile(this.sourceFile)) {
	    if (this.doDeleteMissing) {
		if (Files.isRegularFile(this.targetFile)) {
		    this.console.outDebug("removing missing: ", this.sourceFile);
		    this.console.outProgress('-');
		    if (!this.doDryRun) {
			Files.delete(this.targetFile);
		    }
		}
		return 0;
	    }
	    throw new IllegalArgumentException("Source file does't exist: path: " + this.sourceFile);
	}

	final FileTime sourceModified = Files.getLastModifiedTime(this.sourceFile);

	if (!this.doOverwriteAll && Files.isRegularFile(this.targetFile)) {
	    final FileTime targetModified = Files.getLastModifiedTime(this.targetFile);
	    if (sourceModified.toMillis() <= targetModified.toMillis()) {
		this.console.outProgress('.');
		return 0;
	    }
	}

	if (!this.doDryRun) {
	    Files.createDirectories(this.targetFile.getParent());
	    if (!Files.isDirectory(this.targetFile.getParent())) {
		throw new IllegalArgumentException(
			"Target folder can't be created: path: " + this.targetFile.getParent());
	    }
	}

	this.console.outDebug("updating: ", this.sourceFile);
	this.console.outProgress('w');
	if (!this.doDryRun) {
	    Files.copy(this.sourceFile, this.targetFile, StandardCopyOption.REPLACE_EXISTING);
	    if (this.doKeepDates) {
		Files.setLastModifiedTime(this.targetFile, sourceModified);
	    }
	}
	++this.updates;
	return 1;
    }

    @Override
    public boolean execute(final OperationContext context) throws Exception {
	if (!context.arguments.hasNext()) {
	    return false;
	}
	for (;;) {
	    final String command = context.arguments.next();
	    final OperationObject<? super FileSyncCommand> operation = FileSyncCommand.OPERATIONS.get(command);
	    if (operation == null) {
		throw new IllegalArgumentException("Unknown option: " + command);
	    }
	    if (!operation.execute(this)) {
		return this.okState;
	    }
	    if (!context.arguments.hasNext()) {
		return true;
	    }
	}
    }

    public void reset() {
	this.sourceFile = null;
	this.targetFile = null;
	this.updates = 0;
	this.doDeleteMissing = false;
	this.doOverwriteAll = false;
    }

    public void setOptions(final FileSyncOption... options) {
	if (options == null) {
	    return;
	}
	option: for (final FileSyncOption option : options) {
	    switch (option) {
	    case DELETE_MISSNG:
		this.doDeleteMissing = true;
		continue option;
	    case OVERWRITE_ALL:
		this.doOverwriteAll = true;
		continue option;
	    case KEEP_DATE:
		this.doKeepDates = true;
		continue option;
	    case DRY_RUN:
		this.doDryRun = true;
		continue option;
	    }
	}
    }

    public void setSourceFile(final Path sourceFile) {
	if (sourceFile == null) {
	    throw new IllegalStateException("sourceFile parameter is null");
	}
	this.sourceFile = sourceFile;
    }

    public void setSourceFile(final String sourceFile) {
	if (sourceFile.trim().isEmpty()) {
	    throw new IllegalStateException("sourceFile parameter is empty");
	}
	this.setSourceFile(Paths.get(sourceFile));
    }

    public void setTargetFile(final Path targetFile) {
	if (targetFile == null) {
	    this.targetFile = null;
	    return;
	}
	if (Files.isDirectory(targetFile)) {
	    throw new IllegalStateException("target file is directory, path: " + targetFile.normalize());
	}
	this.targetFile = targetFile;
    }

    public void setTargetFile(final String targetFile) {
	if (targetFile.trim().isEmpty()) {
	    this.targetFile = null;
	    return;
	}
	this.setTargetFile(Paths.get(targetFile));
    }

}
