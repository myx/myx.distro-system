package ru.myx.distro.prepare;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * MakeIndices "pkg-path" "repo-output"
 *
 * @author myx
 *
 */
public final class MakeSourceIndices {

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	if (args.length < 2) {
	    System.err.println(MakeSourceIndices.class.getSimpleName() + ": 'source-root' 'output-root'");
	    Runtime.getRuntime().exit(-1);
	    return;
	}

	final Path sourceRoot = Paths.get(args[0]);
	if (!Files.isDirectory(sourceRoot)) {
	    System.err.println(MakeSourceIndices.class.getSimpleName() + ": source-root is not a directory");
	    Runtime.getRuntime().exit(-2);
	    return;
	}

	final Path outputRoot = Paths.get(args[1]);
	if (!Files.isDirectory(outputRoot)) {
	    System.err.println(MakeSourceIndices.class.getSimpleName() + ": output-root is not a directory");
	    Runtime.getRuntime().exit(-3);
	    return;
	}

	final ConsoleOutput console = new ConsoleOutput();
	final Distro repositories = new Distro();
	repositories.loadFromLocalSource(console, sourceRoot);
	repositories.buildPrepareIndexFromSource(outputRoot, sourceRoot);
    }

}
