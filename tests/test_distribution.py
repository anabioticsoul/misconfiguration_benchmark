from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from agents.manager.dataset import (
    export_public_dataset,
    validate_image_distributions,
)
from agents.manager.distribution import (
    RegistryConfig,
    login_registry,
    push_registry_image,
    record_image_distribution,
)
from agents.manager.settings import load_repository_env
from agents.manager.validation import load_case_documents


REPO_ROOT = Path(__file__).resolve().parents[1]
TEST_DIGEST = "sha256:" + "a" * 64


class DistributionTest(unittest.TestCase):
    def test_repository_env_loads_values_without_overriding_process_env(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            root = Path(temporary_dir)
            (root / ".env").write_text(
                "HF_TOKEN=from-file\n"
                "MISCONFIGBENCH_HF_REPO=example/bench\n",
                encoding="utf-8",
            )
            with patch.dict(
                os.environ,
                {"HF_TOKEN": "from-process"},
                clear=True,
            ):
                loaded = load_repository_env(root)

                self.assertTrue(loaded)
                self.assertEqual(os.environ["HF_TOKEN"], "from-process")
                self.assertEqual(
                    os.environ["MISCONFIGBENCH_HF_REPO"],
                    "example/bench",
                )

    def test_registry_login_passes_token_through_stdin(self) -> None:
        completed = SimpleNamespace(returncode=0, stdout="", stderr="")
        with patch(
            "agents.manager.distribution.subprocess.run",
            return_value=completed,
        ) as run:
            login_registry("docker.io", "example", "secret-token")

        command = run.call_args.args[0]
        self.assertNotIn("secret-token", command)
        self.assertEqual(run.call_args.kwargs["input"], "secret-token")
        self.assertIn("--password-stdin", command)

    def test_registry_reference_is_versioned(self) -> None:
        config = RegistryConfig(namespace="example")

        self.assertEqual(
            config.image_reference("CA35", "0.2"),
            "docker.io/example/misconfigbench-ca35:v0.2",
        )

    def test_push_records_digest_from_docker_output(self) -> None:
        completed = SimpleNamespace(
            returncode=0,
            stdout=f"latest: digest: {TEST_DIGEST} size: 1234\n",
            stderr="",
        )
        with patch(
            "agents.manager.distribution._run",
            return_value=completed,
        ) as run:
            distribution = push_registry_image(
                "ca35:latest",
                "CA35",
                "0.2",
                RegistryConfig(namespace="example"),
            )

        self.assertEqual(distribution["digest"], TEST_DIGEST)
        self.assertEqual(
            distribution["pull_reference"],
            f"docker.io/example/misconfigbench-ca35@{TEST_DIGEST}",
        )
        self.assertEqual(run.call_count, 3)

    def test_recorded_distribution_follows_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            case_dir = Path(temporary_dir) / "CA35"
            source = REPO_ROOT / "instances/CA35"
            import shutil

            shutil.copytree(source, case_dir)
            record_image_distribution(
                case_dir / "instance.json",
                {
                    "type": "docker_registry",
                    "reference": "docker.io/example/misconfigbench-ca35:v0.2",
                    "digest": TEST_DIGEST,
                    "pull_reference": (
                        "docker.io/example/misconfigbench-ca35@" + TEST_DIGEST
                    ),
                },
            )

            manifest, _ = load_case_documents(case_dir)

        self.assertEqual(
            manifest["image"]["distribution"]["digest"],
            TEST_DIGEST,
        )

    def test_public_dataset_excludes_private_oracle(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            dataset_path = export_public_dataset(
                REPO_ROOT,
                Path(temporary_dir),
            )
            records = [
                json.loads(line)
                for line in dataset_path.read_text(encoding="utf-8").splitlines()
            ]

        self.assertGreaterEqual(len(records), 4)
        self.assertNotIn("private_oracle", records[0])
        self.assertNotIn("reference_patch", records[0])
        self.assertIn("problem_statement", records[0])

    def test_dataset_upload_requires_published_images(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            dataset_path = Path(temporary_dir) / "data.jsonl"
            dataset_path.write_text(
                json.dumps(
                    {
                        "instance_id": "CA35",
                        "image": {"name": "ca35:latest"},
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(
                ValueError,
                "missing image distribution for: CA35",
            ):
                validate_image_distributions(dataset_path)


if __name__ == "__main__":
    unittest.main()
