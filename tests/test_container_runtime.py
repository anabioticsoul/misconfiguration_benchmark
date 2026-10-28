from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import patch

from agents.manager.container_runtime import ContainerRuntime, _inspect_has_start_command


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

    def test_execute_can_run_as_an_unprivileged_container_user(self) -> None:
        runtime = ContainerRuntime(SimpleNamespace(), container_name="case-test")
        completed = SimpleNamespace(returncode=0, stdout="ok", stderr="")

        with patch.object(runtime, "_run", return_value=completed) as run:
            result = runtime.execute("id", user="65534:65534")

        self.assertEqual(result.exit_code, 0)
        self.assertEqual(
            run.call_args.args[0],
            [
                "docker",
                "exec",
                "--user",
                "65534:65534",
                "case-test",
                "bash",
                "-lc",
                "id",
            ],
        )


if __name__ == "__main__":
    unittest.main()
