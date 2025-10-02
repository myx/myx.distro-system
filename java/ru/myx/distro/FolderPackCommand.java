package ru.myx.distro;

import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.FileTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import ru.myx.distro.prepare.ConsoleOutput;

public class FolderPackCommand extends FolderScanCommand {
    public static final Map<String, OperationObject<? super FolderPackCommand>> OPERATIONS;
    static {
	OPERATIONS = new HashMap<>();
	FolderPackCommand.OPERATIONS.putAll(AbstractCommand.OPERATIONS);

	final Map<String, OperationObject<FolderPackCommand>> operations = new HashMap<>();

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
		context.doKeepDate = true;
		return true;
	    }, "--keep-date");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doAppendExtension = true;
		return true;
	    }, "--append-extension");
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
		context.setTargetFile(context.arguments.next().trim());
		return true;
	    }, "--target");
	    AbstractCommand.registerOperation(operations, context -> {
		context.doPack();
		return true;
	    }, "--do-pack-continue-always");
	    AbstractCommand.registerOperation(operations, context -> {
		return context.doPack() > 0;
	    }, "--do-pack");
	    AbstractCommand.registerOperation(operations, context -> {
		System.out.println(context.updates);
		return true;
	    }, "--print-updates");
	}

	FolderPackCommand.OPERATIONS.putAll(operations);
    }

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final FolderPackCommand context = new FolderPackCommand();
	context.console = new ConsoleOutput();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, FolderPackCommand.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    private Path targetFile = null;

    public boolean doOverwriteAll = false;
    public boolean doDeleteMissing = false;
    public boolean doKeepDate = false;
    public boolean doAppendExtension = false;
    public boolean doDryRun = false;

    int updates = 0;

    private boolean loadedMaps = false;

    public FolderPackType pack;

    protected FolderPackCommand(final FolderPackOption... options) {
	if (options != null) {
	    this.setOptions(options);
	}
    }

    @SuppressWarnings("boxing")
    public int doPack() throws Exception {

	if (this.pack == null) {
	    throw new IllegalStateException("pack is not set!");
	}

	if (this.targetFile == null) {
	    throw new IllegalStateException("targetFile is not set!");
	}

	final Path targetFile = this.doAppendExtension
		? this.targetFile.resolveSibling(this.targetFile.getFileName() + "." + this.pack.getExtension())
		: this.targetFile;

	if (Files.isDirectory(targetFile)) {
	    throw new IllegalStateException("target file is directory, path: " + targetFile.normalize());
	}

	if (!this.loadedMaps) {
	    this.doPreloadBytes = true;
	    this.doScan();
	    this.loadedMaps = true;
	}

	if (this.selectedFiles == 0 && this.doDeleteMissing) {
	    if (Files.isRegularFile(targetFile)) {
		if (!this.doDryRun) {
		    Files.delete(targetFile);
		}
		this.console.outProgress('-');
	    }
	    return 1;
	}

	if (!this.doOverwriteAll && Files.isRegularFile(targetFile)
		&& this.selectedYoungest == Files.getLastModifiedTime(targetFile).toMillis()) {
	    this.console.outProgress('.');
	    return 0;
	}

	final long timeStarted = System.currentTimeMillis();

	final ByteArrayOutputStream bos = new ByteArrayOutputStream();
	this.pack.doPack(this, bos);

	final long packedSize = bos.size();

	final long duration = System.currentTimeMillis() - timeStarted;

	this.console.outDebug("packed, type: ", this.pack, ", inputSize: ", this.selectedBytes, ", output size: ",
		packedSize, ", took: ", duration, "ms");

	if (!this.doOverwriteAll && Files.isRegularFile(targetFile) && Files.size(targetFile) == packedSize
		&& this.selectedYoungest <= Files.getLastModifiedTime(targetFile).toMillis()) {
	    this.console.outProgress('.');
	    return 0;
	}

	if (!this.doDryRun) {
	    Files.write(targetFile, bos.toByteArray());
	    if (this.doKeepDate) {
		Files.setLastModifiedTime(targetFile, FileTime.fromMillis(this.selectedYoungest));
	    }
	}
	this.console.outProgress('W');

	return 1;
    }

    public int doPackAllTypes() throws Exception {
	if (!this.doAppendExtension) {
	    throw new IllegalArgumentException("--append-extension must be enabled for --pack-all-types");
	}
	if (this.pack != null) {
	    throw new IllegalStateException("pack should not be set for --pack-all-types");
	}

	int result = 0;

	for (final FolderPackType pack : FolderPackType.TRY) {
	    this.setPackType(pack);
	    result += this.doPack();
	}

	return result;
    }

    @Override
    public void doReset() {
	super.doReset();
	this.doDeleteMissing = false;
	this.doKeepDate = false;
	this.doAbsolutePaths = false;
	this.doDryRun = false;
	this.loadedMaps = false;
	this.pack = null;
    }

    @Override
    protected void doResetCaches() {
	this.loadedMaps = false;
    }

    public void setOptions(final FolderPackOption... options) {
	if (options == null) {
	    return;
	}
	option: for (final FolderPackOption option : options) {
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
	    case KEEP_DATE:
		this.doKeepDate = true;
		continue option;
	    case APPEND_EXTENSION:
		this.doAppendExtension = true;
		continue option;
	    case DRY_RUN:
		this.doDryRun = true;
		continue option;
	    }
	}
    }

    public void setPackType(final FolderPackType pack) {
	this.pack = pack;
    }

    public void setTargetFile(final Path targetFile) {
	if (targetFile == null) {
	    this.targetFile = null;
	    return;
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
