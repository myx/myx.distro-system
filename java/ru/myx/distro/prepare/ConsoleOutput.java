package ru.myx.distro.prepare;

import java.util.LinkedHashSet;
import java.util.Set;

public class ConsoleOutput {
    private enum STATE {
	NEW_LINE, CHAR_PROGRESS, STRING_PROGRESS, NRML_PROGRESS
    }

    private boolean silent;

    private boolean verbose;

    private boolean debug;

    private Set<String> errors = new LinkedHashSet<>();

    private STATE lastState = STATE.NEW_LINE;

    public ConsoleOutput() {
	this.silent = false;
	this.verbose = false;
	this.debug = false;
    }

    public ConsoleOutput(final boolean silent, final boolean verbose) {
	this.silent = silent;
	this.verbose = verbose;
    }

    public boolean isDebug() {
	return this.debug;
    }

    public boolean isSilent() {
	return this.silent;
    }

    public boolean isVerbose() {
	return this.verbose;
    }

    public String[] clearCollectedErrors() {
	try {
	    return this.errors.toArray(new String[this.errors.size()]);
	} finally {
	    this.errors.clear();
	}
    }

    public void out(final String s) {
	switch (this.lastState) {
	case NRML_PROGRESS:
	    this.outProgressDefaultStop();
	    //$FALL-THROUGH$
	case CHAR_PROGRESS:
	case STRING_PROGRESS:
	    System.err.println("...");
	    //$FALL-THROUGH$
	case NEW_LINE:
	}
	System.out.println(s);
	this.lastState = STATE.NEW_LINE;
    }

    public void outDebug(final Object... s) {
	if (!this.debug && this.verbose) {
	    if (!this.silent && this.lastState == STATE.NRML_PROGRESS) {
		this.outProgressDefault();
	    }
	    return;
	}
	if (this.debug) {
	    switch (this.lastState) {
	    case NRML_PROGRESS:
		this.outProgressDefaultStop();
		//$FALL-THROUGH$
	    case CHAR_PROGRESS:
	    case STRING_PROGRESS:
		System.err.println("...");
		//$FALL-THROUGH$
	    case NEW_LINE:
	    }

	    final StringBuilder builder = new StringBuilder();
	    builder.append("    :::");

	    final StackTraceElement[] trace = new Error().getStackTrace();
	    if (trace != null && trace.length > 1) {
		final String methodName = trace[1].getMethodName();
		if (methodName != null && !methodName.isEmpty()) {
		    builder//
			    .append(' ')//
			    .append(methodName)//
		    ;
		}
		final String fileName = trace[1].getFileName();
		if (fileName != null && !fileName.isEmpty()) {
		    builder//
			    .append('(')//
			    .append(fileName)//
			    .append(':')//
			    .append(trace[1].getLineNumber())//
			    .append(')')//
		    ;
		}
	    }
	    builder.append(':').append(' ');

	    for (final Object x : s) {
		builder.append(x);
	    }

	    System.err.println(builder.toString());

	    this.lastState = STATE.NEW_LINE;
	}
    }

    public void outInfo(final String s) {
	if (!this.silent) {
	    switch (this.lastState) {
	    case NRML_PROGRESS:
		this.outProgressDefaultStop();
		//$FALL-THROUGH$
	    case CHAR_PROGRESS:
	    case STRING_PROGRESS:
		System.err.println("...");
		//$FALL-THROUGH$
	    case NEW_LINE:
	    }
	    System.err.println(s);
	    this.lastState = STATE.NEW_LINE;
	}
    }

    private long lastProgressDate = 0;
    private int lastProgressIndex = 0;
    private static char[] NORMAL_PROGRESS_FIRST = " . . . . '-.-'-.-96@$%/".toCharArray();
    private static char[] NORMAL_PROGRESS_NEXT = "-\\|/-\\!/".toCharArray();

    private void outProgressDefault() {
	final long dateCurrent = System.currentTimeMillis();

	if (this.lastState == STATE.NRML_PROGRESS) {
	    if (this.lastState == STATE.NRML_PROGRESS && dateCurrent - this.lastProgressDate < 130L) {
		return;
	    }
	    System.err.print('\b');
	} else {
	    this.lastState = STATE.NRML_PROGRESS;
	    this.lastProgressIndex = -NORMAL_PROGRESS_FIRST.length;
	}

	this.lastProgressDate = dateCurrent;
	final int index = this.lastProgressIndex++;

	System.err.print(
		index < 0 ? NORMAL_PROGRESS_FIRST[(NORMAL_PROGRESS_FIRST.length + index) % NORMAL_PROGRESS_FIRST.length]
			: NORMAL_PROGRESS_NEXT[index % NORMAL_PROGRESS_NEXT.length]);
    }

    private void outProgressDefaultStop() {
	if (this.lastState == STATE.NRML_PROGRESS) {
	    System.err.print("\b \b");
	}
	this.lastProgressDate = 0;
    }

    public void outProgress(final char c) {
	if (this.silent) {
	    return;
	}
	if (this.verbose) {
	    switch (this.lastState) {
	    case NRML_PROGRESS:
		this.outProgressDefaultStop();
		//$FALL-THROUGH$
	    case STRING_PROGRESS:
		System.err.println("...");
		//$FALL-THROUGH$
	    case NEW_LINE:
		System.err.print("  ");
		//$FALL-THROUGH$
	    case CHAR_PROGRESS:
	    }
	    System.err.print(c);
	    this.lastState = STATE.CHAR_PROGRESS;
	    return;
	}
	{
	    this.outProgressDefault();
	    return;
	}
    }

    public void outProgress(final String s) {
	if (this.silent) {
	    return;
	}
	if (this.verbose) {
	    switch (this.lastState) {
	    case NRML_PROGRESS:
		this.outProgressDefaultStop();
		//$FALL-THROUGH$
	    case STRING_PROGRESS:
		System.err.println("...");
		//$FALL-THROUGH$
	    case NEW_LINE:
		System.err.print("  ...");
		//$FALL-THROUGH$
	    case CHAR_PROGRESS:
	    }
	    System.err.print(s);
	    this.lastState = STATE.CHAR_PROGRESS;
	    return;
	}
	{
	    this.outProgressDefault();
	    return;
	}
    }

    public void outProgressLine(final String s) {
	if (this.silent) {
	    return;
	}
	if (this.verbose) {
	    switch (this.lastState) {
	    case NRML_PROGRESS:
		this.outProgressDefaultStop();
		//$FALL-THROUGH$
	    case CHAR_PROGRESS:
	    case STRING_PROGRESS:
		System.err.println("...");
		//$FALL-THROUGH$
	    case NEW_LINE:
		System.err.print("  ...");
	    }
	    System.err.print(s);
	    this.lastState = STATE.STRING_PROGRESS;
	    return;
	}
	{
	    this.outProgressDefault();
	    return;
	}
    }

    public void outError(final String s) {
	if (this.errors.add("⛔ " + s)) {
	    this.outWarn("⛔ " + s);
	}
    }

    public void outWarn(final String s) {
	switch (this.lastState) {
	case NRML_PROGRESS:
	    this.outProgressDefaultStop();
	    //$FALL-THROUGH$
	case CHAR_PROGRESS:
	case STRING_PROGRESS:
	    System.err.println("...");
	    //$FALL-THROUGH$
	case NEW_LINE:
	}
	System.err.println(s);
	this.lastState = STATE.NEW_LINE;
    }

    public void setDebug() {
	this.debug = true;
    }

    public void setDebug(final boolean debug) {
	this.debug = debug;
    }

    public void setSilent() {
	this.silent = true;
    }

    public void setSilent(final boolean silent) {
	this.silent = silent;
    }

    public void setVerbose() {
	this.verbose = true;
    }

    public void setVerbose(final boolean verbose) {
	this.verbose = verbose;
    }
}
