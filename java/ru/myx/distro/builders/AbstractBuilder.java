package ru.myx.distro.builders;

import ru.myx.distro.AbstractDistroCommand;
import ru.myx.distro.prepare.OptionListItem;

public interface AbstractBuilder {
    enum BuildStage {
	DONE_CLEAN_TEMP, //
    }

    void build(AbstractDistroCommand context, OptionListItem targets, BuildStage stage);
}
