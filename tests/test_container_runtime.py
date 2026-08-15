from __future__ import annotations

import unittest

from agents.manager.container_runtime import _inspect_has_start_command


class ContainerRuntimeTest(unittest.TestCase):
    def test_docker_image_requires_a_start_command(self) -> None:
        self.assertFalse(_inspect_has_start_command('[{"Config": {}}]'))
        self.assertFalse(
            _inspect_has_start_command(
                '[{"Config": {"Entrypoint": null, "Cmd": null}}]'
            )
        )
        self.assertTrue(
            _inspect_has_start_command(
                '[{"Config": {"Entrypoint": ["/entrypoint.sh"], "Cmd": ["mysqld"]}}]'
            )
        )


if __name__ == "__main__":
    unittest.main()
