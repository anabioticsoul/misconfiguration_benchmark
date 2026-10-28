# CD100 build requirements

- Use the clean `ubuntu:22.04` source image.
- The base layer must contain Python 3 and the settings validation command.
- The base settings file has global `editor.tabSize` and `editor.insertSpaces` defaults.
- The fault layer must omit the Python language-specific settings block.
- Do not copy benchmark metadata or harnesses into the image.
