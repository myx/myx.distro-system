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
public final class MakeOutputIndices {

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	if (args.length < 2) {
	    System.err.println("MakeIndices 'pkg-path' 'repo-output'");
	    Runtime.getRuntime().exit(-1);
	    return;
	}

	final Path outputRoot = Paths.get(args[1]);
	if (!Files.isDirectory(outputRoot)) {
	    System.err.println(MakeSourceIndices.class.getSimpleName() + ": output-root is not a directory");
	    Runtime.getRuntime().exit(-3);
	    return;
	}

	final Distro repositories = new Distro();
	repositories.loadLocalOutputFolders(outputRoot);
	repositories.buildOutputIndices(outputRoot);
    }

}
