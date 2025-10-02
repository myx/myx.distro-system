package ru.myx.distro.prepare;

import java.util.Collection;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.StringTokenizer;

/**
 *
 * Example1: ae3.base Example2: ae3.base:recommended Example3:
 * ae3.base:build.java|minial Example4: build.freebsd-installer:host/install
 * build.freebsd-installer-after:host/install
 *
 *
 * @author myx
 *
 */
public class OptionListItem implements Comparable<OptionListItem> {
    String name;
    Collection<String> keys;

    public OptionListItem(final String listItemSpec) {
	this.keys = new LinkedHashSet<>();
	final int pos = listItemSpec.indexOf(':');
	if (pos == -1) {
	    this.name = listItemSpec;
	} else {
	    this.name = listItemSpec.substring(0, pos).trim();
	    final String listItemKeywords = listItemSpec.substring(pos + 1);
	    final StringTokenizer st = new StringTokenizer(listItemKeywords, "|");
	    for (; st.hasMoreTokens();) {
		this.keys.add(st.nextToken().trim());
	    }
	}
    }

    public OptionListItem(final String listItemName, final String listItemKeywords) {
	this.keys = new LinkedHashSet<>();
	this.name = listItemName;
	if (listItemKeywords != null) {
	    final StringTokenizer st = new StringTokenizer(listItemKeywords, "|");
	    for (; st.hasMoreTokens();) {
		this.keys.add(st.nextToken().trim());
	    }
	}
    }

    public OptionListItem(final String listItemName, final String... listItemKeywords) {
	this.keys = new LinkedHashSet<>();
	this.name = listItemName;
	if (listItemKeywords != null) {
	    for (final String key : listItemKeywords) {
		this.keys.add(key.trim());
	    }
	}
    }

    @Override
    public int compareTo(final OptionListItem o) {
	if (o == null) {
	    return -1;
	}
	return this.name.compareTo(o.name);
    }

    @Override
    public boolean equals(final Object obj) {
	if (this == obj) {
	    return true;
	}
	if (obj == null) {
	    return false;
	}
	if (this.getClass() != obj.getClass()) {
	    return false;
	}
	final OptionListItem other = (OptionListItem) obj;
	if (this.keys == null) {
	    if (other.keys != null) {
		return false;
	    }
	} else if (!this.keys.equals(other.keys)) {
	    return false;
	}
	if (this.name == null) {
	    if (other.name != null) {
		return false;
	    }
	} else if (!this.name.equals(other.name)) {
	    return false;
	}
	return true;
    }

    public String getName() {
	return this.name;
    }

    @Override
    public int hashCode() {
	final int prime = 31;
	int result = 1;
	result = prime * result + (this.keys == null ? 0 : this.keys.hashCode());
	result = prime * result + (this.name == null ? 0 : this.name.hashCode());
	return result;
    }

    public boolean hasKey(final String key) {
	return this.keys.contains(key);
    }

    public void resetKeys() {
	this.keys.clear();
    }

    public void fillList(final String prefix, final Collection<String> target) {
	final Iterator<String> keys = this.keys.iterator();
	if (!keys.hasNext()) {
	    if (prefix != null) {
		target.add(prefix + this.name);
		return;
	    }
	    target.add(this.name);
	    return;
	}
	final StringBuilder text = new StringBuilder(32);
	for (;;) {
	    if (prefix != null) {
		text.append(prefix);
	    }
	    text.append(this.name);
	    final String key = keys.next();
	    if (key != null && !key.isEmpty()) {
		text.append(':').append(key);
	    }
	    target.add(text.toString());
	    text.setLength(0);
	    if (!keys.hasNext()) {
		return;
	    }
	}
    }

    @Override
    public String toString() {
	final Iterator<String> keys = this.keys.iterator();
	if (!keys.hasNext()) {
	    return this.name;
	}
	final StringBuilder text = new StringBuilder(32);
	text.append(this.name).append(':');
	for (;;) {
	    text.append(keys.next());
	    if (keys.hasNext()) {
		text.append('|');
		continue;
	    }
	    return text.toString();
	}
    }
}
