package ru.myx.distro.prepare;

import java.io.File;
import java.io.IOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;

import javax.annotation.processing.Processor;
import javax.tools.Diagnostic;
import javax.tools.DiagnosticListener;
import javax.tools.JavaCompiler;
import javax.tools.JavaFileObject;
import javax.tools.StandardJavaFileManager;
import javax.tools.StandardLocation;
import javax.tools.ToolProvider;

public class MakeCompileJava {
    final class DiagnosticOutput implements DiagnosticListener<JavaFileObject> {
	private final MakeCompileJava compileLog;

	int errors = 0;

	DiagnosticOutput(final MakeCompileJava compileLog) {
	    this.compileLog = compileLog;
	}

	@Override
	public void report(final Diagnostic<? extends JavaFileObject> d) {
	    final Diagnostic.Kind kind = d.getKind();
	    switch (kind) {
	    case ERROR:
		++this.errors;
		if (this.compileLog != null) {
		    this.compileLog.log("ERR: " + d);
		}
		System.err.print('!');
		return;
	    case WARNING:
		if (this.compileLog != null) {
		    this.compileLog.log("WRN: " + d);
		}
		System.err.print('W');
		return;
	    case MANDATORY_WARNING:
		if (this.compileLog != null) {
		    this.compileLog.log("MWN: " + d);
		}
		System.err.print('M');
		return;
	    default:
		System.err.print('O');
		return;
	    }
	}
    }

    static class OutputWriter extends Writer {
	private final MakeCompileJava compileLog;

	OutputWriter(final MakeCompileJava compileLog) {
	    this.compileLog = compileLog;
	}

	@Override
	public void close() throws IOException {
	    //
	}

	@Override
	public void flush() throws IOException {
	    //

	}

	@Override
	public void write(final char[] cbuf, final int off, final int len) throws IOException {
	    this.compileLog.log("out: " + new String(cbuf, off, len));

	}

    }

    public static void main(final String[] args) throws Exception {
	if (args.length < 2) {
	    System.err.println(MakeCompileJava.class.getSimpleName() + ": 'source-root' 'output-root'");
	    Runtime.getRuntime().exit(-1);
	    return;
	}

	final Path sourceRoot = Paths.get(args[0]);
	if (!Files.isDirectory(sourceRoot)) {
	    System.err.println(MakeCompileJava.class.getSimpleName() + ": source-root is not a directory");
	    Runtime.getRuntime().exit(-2);
	    return;
	}

	final Path outputRoot = Paths.get(args[1]);
	if (!Files.isDirectory(outputRoot)) {
	    System.err.println(MakeCompileJava.class.getSimpleName() + ": output-root is not a directory");
	    Runtime.getRuntime().exit(-3);
	    return;
	}

	new MakeCompileJava(sourceRoot, outputRoot);
    }

    final List<File> classPaths = new ArrayList<>();
    final Path compileLog;

    final JavaCompiler compiler;

    final DiagnosticOutput diagnostics;
    final Path outputRoot;

    final List<File> sourcePaths = new ArrayList<>();

    final Path sourceRoot;

    boolean sourcesFromOutput = false;

    ConsoleOutput console = null;

    MakeCompileJava(final Path sourceRoot, final Path outputRoot) throws Exception {
	this.sourceRoot = sourceRoot;
	this.outputRoot = outputRoot;

	this.compiler = ToolProvider.getSystemJavaCompiler();

	this.compileLog = outputRoot.resolve("cached").resolve("compile.log.txt");

	this.diagnostics = new DiagnosticOutput(this);

	this.log("RUN: Compilator created, unixtime: " + System.currentTimeMillis());

	{
	    for (final String classPath : Files
		    .readAllLines(outputRoot.resolve("cached").resolve("distro-classpath.txt"))) {
		this.classPaths.add(new File(classPath));

		this.log("      class-path: " + classPath);
	    }

	}
	{
	    for (final String sourcePath : Files
		    .readAllLines(outputRoot.resolve("cached").resolve("java-sourcepath.txt"))) {
		this.sourcePaths.add(new File(sourcePath));

		this.log("      source-path: " + sourcePath);
	    }
	}
    }

    boolean compileBatch(final Path targetPath, final Iterable<File> sourcePaths, final Iterable<File> fileNames)
	    throws Exception {
	boolean result = true;
	try (final StandardJavaFileManager fileManager = this.compiler.getStandardFileManager(this.diagnostics, null,
		StandardCharsets.UTF_8)) {

	    fileManager.setLocation(StandardLocation.CLASS_PATH, this.classPaths);
	    // fileManager.setLocation(StandardLocation.SOURCE_PATH,
	    // this.sourcePaths);
	    fileManager.setLocation(StandardLocation.SOURCE_PATH, sourcePaths);
	    fileManager.setLocation(StandardLocation.CLASS_OUTPUT, Arrays.asList(targetPath.toFile()));

	    this.log("RUN: Compiler Task   target-folder:" + targetPath);

	    final List<String> options = Arrays.asList(//
		    "-g:lines", //
		    "-Xlint:none", //
		    "-proc:none", //
		    // "-implicit:none", //
		    // "-Xprefer:source", //
		    "-Xprefer:newer", //
		    // "-Xmaxerrors", "512", //
		    "-verbose", //
		    "-verbose", //
		    "-source", "8", //
		    "-target", "8" //
	    );

	    boolean itemResult = true;
	    if (true) {
		final List<Processor> EMPTY_PROC = Collections.emptyList();

		final List<JavaFileObject> fileObjects = new ArrayList<>();
		for (final Iterator<File> fileIterator = fileNames.iterator();;) {

		    if (!fileIterator.hasNext() || fileObjects.size() >= 1024) {

			this.log("RUN: Compiler Flush: count: " + fileObjects.size());

			if (fileObjects.size() > 0) {
			    final JavaCompiler.CompilationTask compileTask = this.compiler.getTask(//
				    new OutputWriter(this), //
				    fileManager, //
				    this.diagnostics, //
				    options, //
				    null, //
				    fileObjects//
			    );

			    compileTask.setProcessors(EMPTY_PROC);
			    itemResult = compileTask.call();
			    System.err.print(itemResult ? 'o' : 'E');
			    if (result && !itemResult) {
				result = false;
			    }

			    this.log("RUN: Compiler flushed: count: " + fileObjects.size());
			    fileObjects.clear();
			}

			if (!fileIterator.hasNext()) {
			    return result;
			}
		    }

		    final File file = fileIterator.next();

		    this.log("RUN: Compiler file: " + file);

		    for (final JavaFileObject fileObject : fileManager.getJavaFileObjects(file)) {
			fileObjects.add(fileObject);
		    }
		    System.err.print('+');
		}
	    }
	    if (true) {
		final Iterable<? extends JavaFileObject> fileObjects = fileManager
			.getJavaFileObjectsFromFiles(fileNames);

		final JavaCompiler.CompilationTask compileTask = this.compiler.getTask(//
			null, //
			fileManager, //
			this.diagnostics, //
			options, //
			null, //
			fileObjects//
		);

		itemResult = compileTask.call();
		if (result && !itemResult) {
		    result = false;
		}
		return result;
	    }
	    for (final File file : fileNames) {
		final Iterable<? extends JavaFileObject> fileObjects = fileManager
			.getJavaFileObjectsFromFiles(Arrays.asList(file));

		final JavaCompiler.CompilationTask compileTask = this.compiler.getTask(//
			null, //
			fileManager, //
			this.diagnostics, //
			options, //
			null, //
			fileObjects//
		);

		itemResult = compileTask.call();
		if (result && !itemResult) {
		    result = false;
		}
	    }
	    return result;
	}
    }

    boolean log(final String message) {
	if (this.compileLog == null) {
	    return false;
	}
	final String x = System.currentTimeMillis() + ": " + message;
	synchronized (this.compileLog) {
	    try {
		Files.write(this.compileLog, //
			Arrays.asList(x), //
			// message.getBytes(StandardCharsets.UTF_8), //
			StandardOpenOption.APPEND, //
			StandardOpenOption.CREATE);
	    } catch (final IOException e) {
		throw new RuntimeException(e);
	    }
	}
	return true;
    }

}
