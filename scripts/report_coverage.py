"""Refresh taxonomy coverage from instance metadata and recorded validation."""

from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

from agents.manager.batch import discover_cases


def validation_records(root: Path) -> dict[str, dict]:
    latest = {}
    for directory, dirs, files in os.walk(root / "runs"):
        dirs[:] = [d for d in dirs if d not in {
            "openhands_state", "instance_workspace", "workspace", ".git", "rendered"
        }]
        for name in ("result.json", "validation.json"):
            if name not in files:
                continue
            path = Path(directory) / name
            try:
                document = json.loads(path.read_text())
                if not isinstance(document, dict):
                    continue
                case_id = document.get("instance_id")
                if name == "validation.json":
                    # Legacy manual repair runs have no instance_id field.
                    match = re.search(r"-(ca|cb|cc|cd)(\d+)-", path.parent.name, re.I)
                    case_id = case_id or ("".join(match.groups()).upper() if match else None)
                    validation = document
                elif document.get("agent_role") == "builder":
                    if document.get("dry_run"):
                        continue
                    validation = document.get("validation", {})
                elif document.get("agent_role") in {"verifier", "builder_validation"} and document.get("verification_kind") != "consistency_review":
                    validation = document
                else:
                    continue
                if not isinstance(validation, dict) or not isinstance(case_id, str):
                    continue
                if not re.fullmatch(r"(?:CA|CB|CC|CD)\d+", case_id):
                    continue
                if "reproduction" not in validation or "reference_evaluation" not in validation:
                    continue
                stamp = document.get("finished_at")
                timestamp = (datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp()
                             if stamp else path.stat().st_mtime)
                passed = (validation.get("success") is True
                          and validation["reproduction"].get("exit_code") == 0
                          and validation["reference_evaluation"].get("exit_code") == 0)
                record = {"timestamp": timestamp, "passed": passed,
                          "source": str(path.relative_to(root))}
                if case_id not in latest or timestamp > latest[case_id]["timestamp"]:
                    latest[case_id] = record
            except (ValueError, OSError, TypeError, AttributeError):
                continue
    return latest


def collect(root: Path) -> dict:
    taxonomy = json.loads((root / "standards/taxonomy.json").read_text())
    complete, skipped = discover_cases(root)
    evidence = validation_records(root)
    rows = {s["id"]: {"rc": t["id"], "rc_name": t["name"],
                       "subtype": s["id"], "name": s["name"],
                       "complete": [], "verified": [], "failed": [], "unknown": []}
            for t in taxonomy["types"] for s in t["subtypes"]}
    issues = []
    for case_id in complete:
        metadata = json.loads((root / "instances" / case_id[:2] / case_id /
                               "meta/metadata.json").read_text())
        subtype = metadata.get("private_oracle", {}).get("classification", {}).get("category_id")
        if subtype not in rows:
            issues.append({"instance_id": case_id, "reason": f"Unknown taxonomy ID: {subtype}"})
            continue
        row = rows[subtype]
        row["complete"].append(case_id)
        record = evidence.get(case_id)
        state = "unknown" if record is None else "verified" if record["passed"] else "failed"
        row[state].append(case_id)
    return {"generated_at": datetime.now(timezone.utc).isoformat(),
            "taxonomy_version": taxonomy["schema_version"], "rows": list(rows.values()),
            "evidence": {i: evidence[i] for i in complete if i in evidence},
            "incomplete": skipped, "issues": issues}


def render(report: dict) -> str:
    rows = report["rows"]
    complete = sum(len(r["complete"]) for r in rows)
    verified = sum(len(r["verified"]) for r in rows)
    lines = ["# Instance 分类覆盖统计", "",
             f"更新时间（UTC）：{report['generated_at']}", "",
             "运行 `python -m scripts.report_coverage` 更新本表及同名 JSON，无需 Docker 或模型 API。", "",
             "统计以 standards/taxonomy.json 和 metadata 的 category_id 为准，不根据 case 编号前缀猜分类。",
             "文件完整不等于验证通过；已复现按最近一次有复现和参考修复结果的 builder/verifier 验证记录计数。",
             "仅生成、dry-run、fixer 修复结果不计入。手动修复 validation.json 按目录中的 case ID 归属。",
             "这是历史验证记录统计，不是重新运行：旧记录未绑定当前文件哈希或镜像 digest，不能保证当前环境仍通过。", "",
             f"文件完整 **{complete}**；最近验证通过 **{verified}**；不完整目录 **{len(report['incomplete'])}**。", "",
             "## RC 汇总", "", "| RC | 名称 | 文件完整 | 验证通过 | 子类覆盖（验证通过） |",
             "|---|---|---:|---:|---:|"]
    for rc in dict.fromkeys(r["rc"] for r in rows):
        group = [r for r in rows if r["rc"] == rc]
        lines.append(f"| {rc} | {group[0]['rc_name']} | {sum(len(r['complete']) for r in group)} | "
                     f"{sum(len(r['verified']) for r in group)} | {sum(bool(r['verified']) for r in group)}/{len(group)} |")
    lines += ["", "## 子类明细", "", "| RC | 子类 | 名称 | 文件完整 | 验证通过 | 已复现 case |",
              "|---|---|---|---:|---:|---|"]
    for r in rows:
        lines.append(f"| {r['rc']} | {r['subtype']} | {r['name']} | {len(r['complete'])} | "
                     f"{len(r['verified'])} | {', '.join(r['verified']) or '-'} |")
    lines += ["", "## 尚未覆盖", ""]
    lines += [f"- {r['subtype']}：{r['name']}" for r in rows if not r["verified"]]
    lines += ["", "## 待验证或最近失败", ""]
    for r in rows:
        for state, label in (("failed", "最近验证失败"), ("unknown", "未找到验证记录")):
            for case_id in r[state]:
                source = report["evidence"].get(case_id, {}).get("source", "-")
                lines.append(f"- {case_id}（{r['subtype']}）：{label}；记录：`{source}`")
    for issue in report["issues"]:
        lines.append(f"- {issue['instance_id']}：{issue['reason']}")
    lines += ["", "逐 case 验证来源和不完整目录原因见同名 JSON；每个 case 只计一次。", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("docs/instance-coverage.md"))
    args = parser.parse_args()
    root = args.repo_root.resolve()
    output = args.output if args.output.is_absolute() else root / args.output
    report = collect(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render(report), encoding="utf-8")
    output.with_suffix(".json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
