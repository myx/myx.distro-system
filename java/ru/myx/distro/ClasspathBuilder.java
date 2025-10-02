package ru.myx.distro;

import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

public class ClasspathBuilder implements Iterable<String> {
    private final List<String> list = new LinkedList<>();
    private final Set<String> set = new TreeSet<>();

    public boolean add(final String item) {
	if (!this.set.add(item)) {
	    return false;
	}
	this.list.add(item);
	return true;
    }

    @Override
    public Iterator<String> iterator() {
	return this.list.iterator();
    }
}
