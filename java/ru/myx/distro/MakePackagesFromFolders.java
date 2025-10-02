package ru.myx.distro;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;

import ru.myx.distro.prepare.ConsoleOutput;
import ru.myx.distro.prepare.Distro;
import ru.myx.distro.prepare.Project;

public class MakePackagesFromFolders extends AbstractDistroCommand {

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final MakePackagesFromFolders context = new MakePackagesFromFolders();
	context.console = new ConsoleOutput();
	context.repositories = new Distro();
	context.arguments = Arrays.asList(args).iterator();

	if (args.length == 0) {
	    AbstractCommand.doPrintSyntax(context, AbstractDistroCommand.OPERATIONS);
	    return;
	}

	context.execute(context);
    }

    @Override
    public boolean execute(final OperationContext context) throws Exception {

	final Path cachedRoot = this.cachedRoot;
	if (!Files.isDirectory(cachedRoot)) {
	    throw new IllegalArgumentException("cached does not exist or not a directory: " + cachedRoot);
	}

	context.console.outDebug("making packages form folders, working at: ", cachedRoot);

	context.console.outDebug("buildQueue size: ", String.valueOf(this.buildQueue.size()));

	for (final Project project : this.buildQueue) {
	    context.console.outDebug("making packages for project: ", project);

	    final Path projectRoot = cachedRoot.resolve(project.repo.name).resolve(project.name);

	    final Path checkJava = projectRoot.resolve("java");
	    if (Files.isDirectory(checkJava)) {

		final FolderPackCommand command = new FolderPackCommand(//
			FolderPackOption.DELETE_MISSNG, //
			FolderPackOption.APPEND_EXTENSION, //
			FolderPackOption.KEEP_DATE //
		);

		command.console = this.console;
		command.addSourceRoot(checkJava);
		command.setTargetFile(checkJava);

		command.doPackAllTypes();
		// command.setPackType(FolderPackType.PACK_JAR);
		// command.doPack();
	    }

	    final Path checkData = projectRoot.resolve("data");
	    if (Files.isDirectory(checkData)) {

		final FolderPackCommand command = new FolderPackCommand(//
			FolderPackOption.DELETE_MISSNG, //
			FolderPackOption.APPEND_EXTENSION, //
			FolderPackOption.KEEP_DATE //
		);

		command.console = this.console;
		command.addSourceRoot(checkData);
		command.setTargetFile(checkData);

		command.doPackAllTypes();
		// command.setPackType(FolderPackType.PACK_TXZ);
		// command.doPack();
	    }

	    final Path checkDocs = projectRoot.resolve("docs");
	    if (Files.isDirectory(checkDocs)) {

		final FolderPackCommand command = new FolderPackCommand(//
			FolderPackOption.DELETE_MISSNG, //
			FolderPackOption.APPEND_EXTENSION, //
			FolderPackOption.KEEP_DATE //
		);

		command.console = this.console;
		command.addSourceRoot(checkDocs);
		command.setTargetFile(checkDocs);

		command.doPackAllTypes();
		// command.setPackType(FolderPackType.PACK_TXZ);
		// command.doPack();
	    }
	}

	return true;
    }

}
