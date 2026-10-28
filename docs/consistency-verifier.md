# Builder 验证与 Verifier 一致性审查

## 职责

- Builder：生成文件、构建镜像、自动执行确定性验证，验证成功才发布实例。
- Verifier：使用 OpenHands 模型审查原始 description、环境、补丁、测试的一致性。
- Evaluator：评估被测模型的诊断/修复能力；批量运行的环境门槛调用 builder
  的确定性验证，不会自动调用审查模型。

正常 builder 入口构建后必定调用共享的 DockerInstanceBuilder.validate：
复现预期故障、修复前 F2P 失败、修复前 P2P 通过、参考补丁 evaluator 通过。
修复后测试是否真的执行仍依赖 case harness 的实现，审查 agent 会检查这种缺陷。
`--dry-run` 只做静态准备，不属于成功复现。

## 运行

仅重新验证已有镜像，不构建、不调用模型：

```sh
python -m agents.builder.run_case CA41 --validate-only --validation-timeout 180
```

一致性审查（会访问配置的模型服务）：

```sh
python -m agents.verifier.run_case CA41 --llm-provider openlux --model YOUR_MODEL
python -m agents.verifier.run_case CA41 --llm-provider openai_subscription --subscription-login --model YOUR_MODEL
```

launch.json 提供以上两种 verifier 模型入口及 builder 验证入口。
Verifier 默认先重新执行同一套确定性验证，再采集实际镜像 ID、平台及允许修改
的容器配置文件，与 case 的源码、脚本、元数据一起形成冻结证据集。
原始 description 从 assets/类别/编号.md 读取，与生成的 description 区分；
原始文件缺失会报错，不默默使用生成描述替代。

## 输出与边界

输出目录：runs/时间戳-verifier-review-编号/。

- evidence.json：有 SHA256 的文本证据、镜像身份、当前容器配置及验证输出。
- task_prompt.md：审查提示词和证据目录。
- trajectory.jsonl、openhands_state：模型工具读取与运行轨迹。
- review.json：description/environment/patch/tests 四项判断、理由和证据引用。
- result.json：模型信息、确定性验证、审查结论、耗时/异常及 token 成本记录。

模型仅有读取冻结证据的工具，无 shell、Docker 或文件写入权限。材料中的
命令和指令视为待审内容，不是执行授权。证据可能含 case 合成凭据，勿在 case
中放生产秘密；使用第三方 API 意味着相关材料会发送给该服务。

结论为 consistent/inconsistent/needs_review；全部四项 pass 才能 consistent，
有截断证据会降为 needs_review。证据 ID 必须存在，但程序不能保证模型理由
的语义正确。最终 success 还必须满足确定性验证通过，模型不能覆盖测试失败。
缺失镜像、环境无法采集、模型错误或非法 JSON 都会失败并保存错误，不算通过。

这不是全面安全证明或自动人工标注：当前运行态采集只覆盖允许修改的配置文件，
不是所有进程、网络、依赖与文件系统。无法支持的结论应标为 uncertain，必要时
补充材料或人工复核。Verifier 审查结果不会混入已复现数量；覆盖统计继续使用
builder 确定性验证以及旧版 verifier 的历史记录。
