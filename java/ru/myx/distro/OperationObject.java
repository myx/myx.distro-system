package ru.myx.distro;

@FunctionalInterface
public interface OperationObject<T extends OperationContext> {

    boolean execute(T context) throws Exception;

}