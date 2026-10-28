Build from ubuntu:22.04. Install GCC 11, its localization catalog package, libc development headers, locale data, bash, and git. Generate en_GB.UTF-8 and ru_RU.UTF-8. Keep the base image free of the case-specific profile setting; the fault overlay sets LANG=ru_RU.UTF-8 persistently for login shells.

Before package installation, remove the minimal image's dpkg exclusion for
LC_MESSAGES catalogs. Assert that the Russian gcc-11.mo file exists: successful
package installation alone does not guarantee that translations were retained.
This is a Linux reproduction of GCC's locale behavior, not a Cygwin runtime.
