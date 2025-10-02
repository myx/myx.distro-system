package ru.myx.distro.prepare;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;

public class OptionList extends LinkedHashSet<OptionListItem> {

    private static final long serialVersionUID = 4464004437970547444L;

    public OptionList() {
    }

    @Override
    public boolean add(final OptionListItem item) {
	// final OptionListItem existing = this.floor(item);
	for (OptionListItem existing : this) {
	    if (existing != null && existing.getName().equals(item.getName())) {
		return existing.keys.addAll(item.keys);
	    }
	}
	return super.add(item);
    }

    @Override
    public String toString() {
	if (this.isEmpty()) {
	    return "";
	}

	final StringBuilder builder = new StringBuilder();
	for (final OptionListItem item : this) {
	    if (builder.length() > 0) {
		builder.append(' ');
	    }
	    final List<String> items = new ArrayList<>();
	    item.fillList(null, items);
	    builder.append(String.join(" ", items));
	}
	return builder.toString();
    }
}
