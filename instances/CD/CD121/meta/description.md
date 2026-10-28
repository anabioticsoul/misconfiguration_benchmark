# Eclipse run configuration name conflict

I synced a Mercurial project and tried to set up run configurations. Eclipse adds `(1)` to the configuration name, and removing it reports: `A configuration with this name already exists`. The other visible configurations do not show a duplicate named `Equivalence Checker`.

How can I find the existing configuration to remove it?

The relevant configuration is associated with a deleted or unavailable project and is hidden by the launch-configuration dialog's **Filter Deleted/Unavailable Projects** filter. Make the existing configuration discoverable so it can be removed, without deleting unrelated configurations.
