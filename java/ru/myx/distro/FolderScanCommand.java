package ru.myx.distro;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Stream;

import ru.myx.distro.prepare.ConsoleOutput;

public class FolderScanCommand extends AbstractCommand {
    protected static class ScanFileBytes extends ScanFileRecord {
	public byte[] bytes;

	public ScanFileBytes(final BasicFileAttributes attributes, final Path file) throws Exception {
	    super(attributes);
	    this.bytes = Files.readAllBytes(file);
	}

	@Override
	public byte[] bytes() throws Exception {
	    return this.bytes;
	}

	@Override
	public boolean copy(final Path path) throws Exception {
	    Files.write(path, this.bytes);
	    Files.setLastModifiedTime(path, FileTime.fromMillis(this.modified));
	    return true;
	}
    }

    protected static class ScanFilePaths extends ScanFileRecord {
	public Path file;

	public ScanFilePaths(final BasicFileAttributes attributes, final Path file) {
	    super(attributes);
	    this.file = file;
	}

	@Override
	public byte[] bytes() throws Exception {
	    return Files.readAllBytes(this.file);
	}

	@Override
	public boolean copy(final Path path) throws Exception {
	    Files.copy(this.file, path, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.COPY_ATTRIBUTES);
	    return true;
	}
    }

    protected static abstract class ScanFileRecord {
	public long modified;
	public long size;

	public ScanFileRecord(final BasicFileAttributes attributes) {
	    this.modified = attributes.lastModifiedTime().toMillis();
	    this.size = attributes.size();
	}

	public abstract byte[] bytes() throws Exception;

	public abstract boolean copy(final Path path) throws Exception;
    }

    protected static class ScanFolderRecord {
	public int count;

	public long modified;

	public ScanFolderRecord(final BasicFileAttributes attributes) {
	    this.modified = attributes.lastModifiedTime().toMillis();
	}
    }

    protected static final Map<String, OperationObject<? super FolderScanCommand>> OPERATIONS;

    static {
	OPERATIONS = new HashMap<>();
	FolderScanCommand.OPERATIONS.putAll(AbstractCommand.OPERATIONS);

	final Map<String, OperationObject<FolderScanCommand>> operations = new HashMap<>();

	{
	    AbstractCommand.registerOperation(operations, context -> {
		context.reset();
		return true;
	    }, "--reset");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doIgnoreHidden = true;
		context.doResetCaches();
		return true;
	    }, "--ignore-hidden");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doPreloadBytes = true;
		context.doResetCaches();
		return true;
	    }, "--preload-bytes");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doAbsolutePaths = true;
		context.doResetCaches();
		return true;
	    }, "--absolute-paths");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("source expected after --source option");
		}
		context.addSourceRoot(context.arguments.next());
		return true;
	    }, "--source");
	    AbstractCommand.registerOperation(operations, context -> {
		if (!context.arguments.hasNext()) {
		    throw new IllegalArgumentException("name expected after --exclude option");
		}
		context.addExcludeName(context.arguments.next());
		return true;
	    }, "--exclude");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doScan();
		return true;
	    }, "--scan");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.selectedFiles + context.selectedFolders);
		return true;
	    }, "--print-selected");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.selectedFiles);
		return true;
	    }, "--print-selected-files");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.selectedFolders);
		return true;
	    }, "--print-selected-folders");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(new Date(context.selectedYoungest));
		return true;
	    }, "--print-selected-youngest");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.selectedBytes);
		return true;
	    }, "--print-selected-bytes");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.knownFolders.keySet());
		return true;
	    }, "--print-selected-folders");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.knownFiles.keySet());
		return true;
	    }, "--print-selected-files");
	}

	FolderScanCommand.OPERATIONS.putAll(operations);
    }

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final FolderScanCommand context = new FolderScanCommand();
	context.console = new ConsoleOutput();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, FolderScanCommand.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    public boolean doIgnoreHidden = false;
    public boolean doPreloadBytes = false;
    public boolean doAbsolutePaths = false;

    public final Set<String> excludeNames = new HashSet<>();

    public final Map<Path, ScanFileRecord> knownFiles = new TreeMap<>();
    public final Map<Path, ScanFolderRecord> knownFolders = new TreeMap<>();

    public int selectedFolders = 0;
    public int selectedFiles = 0;
    public long selectedYoungest = 0;
    public long selectedBytes = 0;

    public final List<Path> sourceRoots = new ArrayList<>();

    public FolderScanCommand() {
	//
    }

    public FolderScanCommand(final FolderScanOption... options) {
	if (options != null) {
	    this.setOptions(options);
	}
    }

    public void addExcludeName(final String string) {
	this.excludeNames.add(string);
	this.doResetCaches();
    }

    public void addSourceRoot(final Path sourceRoot) {
	if (sourceRoot == null) {
	    throw new IllegalStateException("sourceRoot parameter is null");
	}
	if (!this.sourceRoots.contains(sourceRoot)) {
	    this.sourceRoots.add(sourceRoot);
	    this.doResetCaches();
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

    protected void doResetCaches() {
	//
    }

    public int doScan() throws Exception {

	if (this.sourceRoots.isEmpty()) {
	    throw new IllegalArgumentException("No sources!");
	}

	this.console.outProgress('S');

	for (final Path sourceRoot : this.sourceRoots) {
	    this.console.outProgress('s');
	    if (!Files.isDirectory(sourceRoot)) {
		if (Files.exists(sourceRoot)) {
		    throw new IllegalArgumentException("sourceRoot is not a directory: " + sourceRoot);
		}
		continue;
	    }
	    try (final Stream<Path> stream = Files.walk(sourceRoot)) {
		stream.forEach(item -> {
		    final String name = item.getFileName().toString();
		    if (name.length() == 0) {
			return;
		    }
		    if (this.doIgnoreHidden && name.charAt(0) == '.') {
			return;
		    }
		    if (this.excludeNames.contains(name)) {
			return;
		    }

		    final Path key = this.doAbsolutePaths ? item : sourceRoot.relativize(item);

		    try {
			final BasicFileAttributes attributes = Files.readAttributes(item, BasicFileAttributes.class);

			if (attributes.isDirectory()) {
			    if (this.knownFolders.containsKey(key)) {
				this.console.outWarn("already scanned: " + key + ", path: " + item);
			    }
			    if (this.knownFolders.put(key, new ScanFolderRecord(attributes)) == null) {
				++this.selectedFolders;
			    }
			    return;
			}
			if (attributes.isRegularFile()) {
			    if (this.knownFolders.containsKey(key)) {
				this.console.outWarn("already scanned: " + key + ", path: " + item);
			    }
			    {
				final long modified = attributes.lastModifiedTime().toMillis();
				final long size = attributes.size();

				if (this.selectedYoungest < modified) {
				    this.selectedYoungest = modified;
				}

				this.selectedBytes += size;
			    }
			    final ScanFileRecord record;
			    if (this.doPreloadBytes) {
				this.console.outProgress("l");
				record = new ScanFileBytes(attributes, item);
			    } else {
				this.console.outProgress("+");
				record = new ScanFilePaths(attributes, item);
			    }
			    if (this.knownFiles.put(key, record) == null) {
				++this.selectedFiles;
			    }
			    return;
			}
			this.console.outWarn("Invalid file type: " + item + ", attributes: " + attributes);
		    } catch (final Exception e) {
			throw new RuntimeException(e);
		    }
		});
	    }
	}

	return this.knownFiles.size() + this.knownFolders.size();
    }

    @Override
    public boolean execute(final OperationContext context) throws Exception {
	this.console.outDebug("Hello!");
	if (!context.arguments.hasNext()) {
	    return false;
	}
	for (;;) {
	    final String command = context.arguments.next();
	    final OperationObject<? super FolderScanCommand> operation = FolderScanCommand.OPERATIONS.get(command);
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
	this.doPreloadBytes = false;
	this.doIgnoreHidden = false;
	this.excludeNames.clear();
	this.selectedFiles = 0;
	this.selectedFolders = 0;
	this.selectedYoungest = 0;
	this.selectedBytes = 0;
	this.knownFiles.clear();
	this.knownFolders.clear();
    }

    public void setOptions(final FolderScanOption... options) {
	if (options == null) {
	    return;
	}
	option: for (final FolderScanOption option : options) {
	    switch (option) {
	    case IGNORE_HIDDEN:
		this.doIgnoreHidden = true;
		continue option;
	    case PRELOAD_BYTES:
		this.doPreloadBytes = true;
		continue option;
	    case ABSOLUTE_PATHS:
		this.doAbsolutePaths = true;
		continue option;
	    }
	}
	this.doResetCaches();
    }
}
