package ru.myx.distro;

import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.FileTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import ru.myx.distro.prepare.ConsoleOutput;

public class FolderSyncCommand extends AbstractCommand {
    protected static final Map<String, OperationObject<? super FolderSyncCommand>> OPERATIONS;
    static {
	OPERATIONS = new HashMap<>();
	FolderSyncCommand.OPERATIONS.putAll(AbstractCommand.OPERATIONS);

	final Map<String, OperationObject<FolderSyncCommand>> operations = new HashMap<>();

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
		context.doIgnoreHidden = true;
		return true;
	    }, "--ignore-hidden");
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
		context.addSourceRoot(context.arguments.next());
		return true;
	    }, "--source");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("target expected after --target option");
		}
		context.setTargetRoot(context.arguments.next().trim());
		return true;
	    }, "--target");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("name expected after --exclude option");
		}
		context.addExcludeName(context.arguments.next());
		return true;
	    }, "--exclude");
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

	FolderSyncCommand.OPERATIONS.putAll(operations);
    }

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final FolderSyncCommand context = new FolderSyncCommand();
	context.console = new ConsoleOutput();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, FolderSyncCommand.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    private final List<Path> sourceRoots = new ArrayList<>();

    private Path targetRoot = null;
    private boolean doOverwriteAll = false;
    private boolean doDeleteMissing = false;
    private boolean doIgnoreHidden = false;
    private boolean doKeepDates = false;
    private boolean doDryRun = false;

    private final Set<String> excludeNames = new HashSet<>();

    int updates = 0;

    protected FolderSyncCommand(final FolderSyncOption... options) {
	if (options != null) {
	    this.setOptions(options);
	}
    }

    public void addExcludeName(final String string) {
	this.excludeNames.add(string);
    }

    public void addSourceRoot(final Path sourceRoot) {
	if (sourceRoot == null) {
	    throw new IllegalStateException("sourceRoot parameter is null");
	}
	if (!this.sourceRoots.contains(sourceRoot)) {
	    if (!Files.isDirectory(sourceRoot)) {
		if (this.doDeleteMissing) {
		    return;
		}
		throw new IllegalStateException("source directory does not exist, path: " + sourceRoot.normalize());
	    }
	    this.sourceRoots.add(sourceRoot);
	}
    }

    public void addSourceRoot(final String sourceRoot) {
	if (sourceRoot.trim().isEmpty()) {
	    throw new IllegalStateException("sourceRoot parameter is empty");
	}
	this.addSourceRoot(Paths.get(sourceRoot));
    }

    public void addSourceRoots(final Iterable<Path> sourceRoots) {
	for (final Path sourceRoot : sourceRoots) {
	    this.addSourceRoot(sourceRoot);
	}
    }

    public int doSync() throws Exception {

	if (this.sourceRoots.isEmpty()) {
	    if (this.doDeleteMissing) {
		if (Files.isDirectory(this.targetRoot)) {
		    this.console.outDebug("sync remove target: ", this.targetRoot);
		    if (!this.doDryRun) {
			Utils.clearFolderContents(this.console, this.targetRoot);
			Files.delete(this.targetRoot);
		    }
		}
		return 0;
	    }
	    throw new IllegalArgumentException("No sources!");
	}

	if (!Files.isDirectory(this.targetRoot)) {
	    this.console.outDebug("sync create target: ", this.targetRoot);
	    if (!this.doDryRun) {
		Files.createDirectories(this.targetRoot);
		if (!Files.isDirectory(this.targetRoot)) {
		    throw new IllegalStateException("Cannot create target directory, path: " + this.targetRoot);
		}
	    }
	}

	final int count = this.sync(null);
	this.updates += count;
	return count;
    }

    @Override
    public boolean execute(final OperationContext context) throws Exception {
	if (!context.arguments.hasNext()) {
	    return false;
	}
	for (;;) {
	    final String command = context.arguments.next();
	    final OperationObject<? super FolderSyncCommand> operation = FolderSyncCommand.OPERATIONS.get(command);
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
	this.sourceRoots.clear();
	this.targetRoot = null;
	this.updates = 0;
	this.doDeleteMissing = false;
	this.doOverwriteAll = false;
	this.doIgnoreHidden = false;
	this.excludeNames.clear();
    }

    public void setOptions(final FolderSyncOption... options) {
	if (options == null) {
	    return;
	}
	option: for (final FolderSyncOption option : options) {
	    switch (option) {
	    case DELETE_MISSNG:
		this.doDeleteMissing = true;
		continue option;
	    case OVERWRITE_ALL:
		this.doOverwriteAll = true;
		continue option;
	    case IGNORE_HIDDEN:
		this.doIgnoreHidden = true;
		continue option;
	    case KEEP_DATES:
		this.doKeepDates = true;
		continue option;
	    case DRY_RUN:
		this.doDryRun = true;
		continue option;
	    }
	}
    }

    public void setTargetRoot(final Path targetRoot) {
	if (targetRoot == null) {
	    this.targetRoot = null;
	    return;
	}
	this.targetRoot = targetRoot;
    }

    public void setTargetRoot(final String targetRoot) {
	if (targetRoot.isEmpty()) {
	    this.targetRoot = null;
	    return;
	}
	this.setTargetRoot(Paths.get(targetRoot));
    }

    private int sync(final Path relativePath) throws Exception {

	this.console.outProgress('S');

	int count = 0;

	final Map<String, Path> ignore = new HashMap<>();
	final Map<String, Path> folders = new HashMap<>();
	for (final Path sourceRoot : this.sourceRoots) {
	    final Path focus = relativePath == null ? sourceRoot : sourceRoot.resolve(relativePath);
	    if (!Files.isDirectory(focus)) {
		continue;
	    }
	    try (DirectoryStream<Path> directoryStream = Files.newDirectoryStream(focus)) {
		this.console.outProgress('*');
		for (final Path path : directoryStream) {
		    final String name = path.getFileName().toString();
		    if (name.length() == 0) {
			continue;
		    }
		    if (this.doIgnoreHidden && name.charAt(0) == '.') {
			continue;
		    }
		    if (this.excludeNames.contains(name)) {
			continue;
		    }
		    if (Files.isDirectory(path)) {
			if (folders.containsKey(name)) {
			    continue;
			}
			folders.put(name, relativePath == null ? path.getFileName() : relativePath.resolve(name));
			continue;
		    }
		    if (ignore.containsKey(name)) {
			continue;
		    }
		    if (Files.isRegularFile(path)) {
			final Path targetFile = //
				(relativePath == null ? this.targetRoot : this.targetRoot.resolve(relativePath)) //
					.resolve(name);
			final long sourceModified = Files.getLastModifiedTime(path).toMillis();
			if (!this.doOverwriteAll && Files.isRegularFile(targetFile)) {
			    if (Files.getLastModifiedTime(targetFile).toMillis() >= sourceModified) {
				// same or newer output exists
				this.console.outProgress('.');
				ignore.put(name, path);
				continue;
			    }
			}
			this.console.outDebug("sync update target: ", targetFile);
			if (!this.doDryRun) {
			    Files.copy(path, targetFile, StandardCopyOption.REPLACE_EXISTING);
			    if (this.doKeepDates) {
				Files.setLastModifiedTime(targetFile, FileTime.fromMillis(sourceModified));
			    }
			}
			this.console.outProgress('w');
			ignore.put(name, path);
			++count;
			continue;
		    }
		}
	    }
	}

	for (final String name : folders.keySet()) {
	    final Path relative = folders.get(name);
	    final Path targetRelative = this.targetRoot.resolve(relative);
	    if (!Files.isDirectory(targetRelative)) {
		this.console.outProgress('d');
		++count;
		Files.createDirectories(targetRelative);
	    }
	    count += this.sync(relative);
	}

	return count;
    }

}
