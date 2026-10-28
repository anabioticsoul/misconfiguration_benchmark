# CC55 build requirements

Use `ubuntu:22.04` as the clean source image. The fixture represents the
IntelliJ IDEA project metadata relevant to the reported Spring Configuration
Check notification. The base overlay contains a Maven project and a correctly
mapped Spring facet; the fault overlay replaces only the module file with the
unmapped form. The image stays alive with an investigation shell because the
reported fault is an IDE project-model configuration issue rather than a
server-startup failure.

The base script only marks the fixture's checker executable. No benchmark
metadata, harnesses, or patches are copied into the image.
