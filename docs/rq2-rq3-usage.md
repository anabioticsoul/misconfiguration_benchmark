# RQ2 / RQ3 运行说明

更新：2026-10-14。代码已提供执行与分析路径；标准答案、证据事实和人工支持性审核仍需要研究者确认，不由程序自动冒充人工审核。

## 1. VS Code 入口

| 入口 | 行为 | 主要参数 |
|---|---|---|
| RQ2: Fixer batch | 批量根因已知修复，提供两种 API 入口 | `--repair-context root_cause`，可改 `location` 或 `none` |
| RQ3: Evidence collection | 在线诊断并记录证据编号，提供两种 API 入口 | `--evidence-mode collect` |
| RQ3: Evidence replay batch | 从审核后的证据包重新诊断，不启动 Docker、不提供环境工具 | 证据包目录、五种重放条件、API/model |
| RQ2/RQ3: Prepare annotation draft | 生成一个待审核标注文件，不修改 instance | case ID、新 JSON 路径 |
| RQ3: Prepare evidence pack | 从观察日志生成待审核证据包 | case ID、观察日志、新 JSON 路径 |
| RQ3: Score human evidence review (offline) | 读取已保存诊断、观察、人工审核进行打分，不调用模型 | 三个文件路径 |
| RQ2/RQ3: Grouped report | 按模型和实验条件汇总，提供描述性配对差值 | runs 目录 |

模型仍直接在 `launch.json` 的 `--model` 处修改。原 Builder、Verifier 和普通离线诊断入口保留。

## 2. RQ2 标注与运行

先生成草稿：

```bash
python -m agents.evaluator.annotations CA151 --output /tmp/CA151-annotations.json
```

填写 `repair_context` 的 component、layer、location、cause、source_kind/source_url、reviewer，确认根因不含修复行、最终值或隐藏测试。审核后将 `review_status` 改为 `reviewed`，把 `repair_context` 合并到对应 `meta/metadata.json` 的 `private_oracle` 下。草稿中的 `instructions` 不合并。

`location` 组仅暴露 component、layer 和 location 的 path/section/option；`root_cause` 再增加 cause。其余字段不渲染给 agent。自由文本根因是否泄漏修复答案仍需人工检查。

```bash
python -m agents.evaluator.run_case --task fixer --all \
  --repair-context none --llm-provider openlux --model <模型>
python -m agents.evaluator.run_case --task fixer --all \
  --repair-context root_cause --llm-provider openlux --model <模型>
```

单 case 用 `CA151` 替换 `--all`。批量模式中缺少审核标注的 case 进入 `batch_result.json.skipped`，不会调用模型；单 case 缺少标注返回退出码 2，并记录 `skipped_missing_oracle`。不会静默回退为 E2E。

新结果保存 `repair_context`、`protocol_version`、prompt 和 case/harness 文件哈希。输出目录在 API/模型后追加实验条件，避免不同条件混淆。

### 执行测试的分项协议

旧 harness 可原样运行，仍返回整体退出码。但整体通过不被推断为所有安全检查通过。

支持分项的 host harness 可把 JSON 写入环境变量 `MISCONFIGBENCH_EVALUATION_RESULT` 指定的文件：

```json
{
  "patch_apply": "pass",
  "policy": "pass",
  "f2p": "pass",
  "p2p": "pass",
  "safety": "not_evaluated"
}
```

每个状态只能是 `pass`、`fail`、`not_evaluated`。任何显式 fail 都会使整体验收失败，即使脚本退出码为 0。未报告项保持 `not_evaluated`；格式非法作为评估错误处理。协议是 host-only 的，不交给被评估 agent。

当前实现没有重写所有 case 的 harness，也没有自动重新分类 CA134 或重定义 CA130/CA147 的任务。之前发现的 case 特定验收问题仍需独立复核，不能将旧测试通过率当作“全部安全检查通过”。

## 3. RQ3 在线证据采集

```bash
python -m agents.evaluator.run_case --task troubleshooter --all \
  --evidence-mode collect --llm-provider openlux --model <模型>
```

每条工具结果带 host 生成的 `obs-0001` 等 ID。新增输出：

- `evidence_observations.jsonl`：命令、返回给模型的文本、退出码、时间和 observation ID。
- `diagnosis.json`：原分类/定位字段，加 symptom/root_cause/localization 三种简短 claim 及 evidence_refs。
- `evidence_result.json`：引用有效性、已标注证据获取状态、人工支持性评分状态。
- `evidence_review.template.json`：绑定当前诊断和观察日志的待审核模板。

标准轨迹 `trajectory.jsonl` 与整体 token/成本记录保留。工具输出编号与原文可在轨迹中交叉检查；没有将其当作内部思维链。

### 证据获取标准

将草稿里的 `evidence_oracle` 审核后合并到 `private_oracle`。每个 fact 的 `alternatives` 是 command_pattern、output_pattern 和 exit_code 的匹配规则；`sufficient_sets` 列出事实 ID 的可替代充分集合。

匹配只发生在真实返回的 observation 上，既检查命令也检查结果。它是经过人工审核的规则匹配，不是自动的因果证明；需要人工抽查误报/漏报，补充等价获取方法。无审核标准时获取率为 null，引用有效性仍能计算。

### 人工支持性审计

审核模板中的三个 judgments 分别填写 `supported`、`unsupported` 或 `missing`，补 reviewer，确认后改为 `reviewed`。缺失的 claim 只能记 missing；supported 必须引用真实 observation。不要修改模板里的 binding_sha256。

```bash
python -m agents.evaluator.run_case --task troubleshooter CA151 \
  --diagnosis-file <运行目录>/diagnosis.json \
  --evidence-mode collect \
  --observations-file <运行目录>/evidence_observations.jsonl \
  --evidence-review <已审核的JSON文件>
```

诊断或观察内容改变后，旧审核会被拒绝。没有人工审核时支持率为 null，不用引用有效率替代支持率。错误引用与不合法 claim 会单独记录 evidence_error，不改变已有分类/定位分数。

离线评分仍放在 offline/unknown 下，不会猜测该诊断由哪个模型生成；不要把离线人工审核结果误并入在线模型成绩。原始运行里的审核模板可通过哈希追溯；目前没有自动把离线审核回写原始运行。

## 4. RQ3 证据重放

先从采集日志准备包：

```bash
python -m agents.evaluator.troubleshooter.evidence_pack CA151 \
  --observations <运行目录>/evidence_observations.jsonl \
  --output /tmp/evidence-packs/CA151.json
```

草稿默认 pending。人工选择 `key_observation_ids` 和不重叠的 `control_observation_ids`；前者须覆盖所选关键事实的全部重复呈现，后者用于相近长度的非关键对照。检查公开描述泄漏、重复证据和对照长度，填写审核字段与说明，再设为 reviewed。现阶段长度匹配由人工审核，不假装已按某个 tokenizer 自动匹配。

观察内容受 observations_sha256 约束；case 文件受 case_sha256 约束。case 或证据改变后需重新准备和审核。不要把旧诊断、模型思考、gold patch 或隐藏测试塞入 observations。

```bash
python -m agents.evaluator.run_case --task troubleshooter CA151 \
  --evidence-mode replay --evidence-pack /tmp/evidence-packs/CA151.json \
  --evidence-condition key_removed --llm-provider openlux --model <模型>
```

批量使用 `--all --evidence-pack-dir /tmp/evidence-packs`，文件名必须是 `<ID>.json`。重放不再运行 verifier，因为它不使用 Docker 环境。重放仍会调用 LLM、消耗 token，不等于离线免费评分。

| 条件 | 模型看到的观察 |
|---|---|
| `full` | 全部观察 |
| `description_only` | 无观察，仅公开描述和分类标准 |
| `key_only` | 关键 observation |
| `key_removed` | 删除全部选定关键 observation 后的剩余内容 |
| `matched_control` | 删除选定非关键对照 observation 后的剩余内容 |

所有条件保持公开描述不变；它已经泄漏的信息不会被代码自动删去。证据包私有标注和其他任意字段通过白名单过滤，不传给模型。重放不能使用 shell 等环境工具；支持性分析仍可执行，但证据“获取率”标为不适用。

## 5. 汇总与限制

```bash
python -m agents.evaluator.report --runs-dir runs --output /tmp/rq-report.json
```

报告按 provider、model、模式、预算、protocol_version 和实验条件分组：

- RQ2：符合条件的运行数、完成验收数、通过率、执行错误数、各分项已知/未知状态。
- RQ3：原诊断指标，以及有测量值的引用有效率、证据获取率和人工支持率；每项均给 measured_runs。
- 配对比较：相同 case 文件快照和镜像引用下，条件组减基线组的平均 per-case 差值；RQ3 还要求相同证据包哈希。重复运行先在 case 内平均。

配对差值目前是描述性结果，不包含置信区间，不宣称因果归因。它仅使用可评分且输入匹配的交集，应同时报告不匹配数量和完整运行完成率。

当前记录的 image_reference 是镜像标签，不是运行时实际镜像内容 digest；正式实验必须固定镜像，不能在同标签下更换内容后直接比较。没有自动做人工标注、双人一致性分析、线上证据通道屏蔽或生产级安全认证。诊断终端的非特权用户和只读提示也不是强制只读沙箱。

不要用程序跑通替代数据质量审核。先完成少量跨类别标注和验收复核，再运行全量模型实验。
