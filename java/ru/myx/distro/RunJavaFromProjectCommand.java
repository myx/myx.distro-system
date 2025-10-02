package ru.myx.distro;

import java.util.Arrays;

import ru.myx.distro.prepare.ConsoleOutput;
import ru.myx.distro.prepare.Distro;

public class RunJavaFromProjectCommand extends AbstractDistroCommand {

    /**
     *
     * @param args
     */
    public static void main(final String[] args) throws Throwable {
	final RunJavaFromProjectCommand context = new RunJavaFromProjectCommand();
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

	return true;
    }

}
