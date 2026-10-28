"""Create pending annotations without changing a case or fabricating review."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from agents.manager.case import CaseDefinition
from agents.manager.paths import instance_dir


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Create a pending RQ2/RQ3 annotation draft for human review.")
    parser.add_argument("instance_id")
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[2]
    case = CaseDefinition.load(instance_dir(root, args.instance_id))
    metadata = json.loads((case.case_dir / "meta/metadata.json").read_text())
    target = metadata["private_oracle"]["faulty_targets"][0]
    draft = {
        "instance_id": case.instance_id,
        "instructions": "Review and merge these fields into private_oracle in meta/metadata.json; do not expose this draft to agents.",
        "repair_context": {
            "review_status": "pending", "reviewer": "", "source_kind": "", "source_url": "",
            "component": case.software_name, "layer": "", "location": target,
            "cause": "", "hint_solution_overlap": "unreviewed",
        },
        "evidence_oracle": {
            "review_status": "pending", "reviewer": "", "source_kind": "",
            "facts": [{"id": "fact-1", "description": "",
                       "alternatives": [{"command_pattern": "", "output_pattern": "", "exit_code": 0}]}],
            "sufficient_sets": [["fact-1"]],
        },
    }
    destination = Path(args.output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(draft, indent=2) + "\n")
    print(f"Pending annotation draft: {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
