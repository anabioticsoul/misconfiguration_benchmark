# MisconfigBench Workflow

MisconfigBench separates instance construction, deterministic validation, agent
repair, and hidden evaluation. This keeps the repair task realistic while
preventing the fixer from observing the reference answer or evaluator.

```mermaid
flowchart TB
    classDef input fill:#e8f1ff,stroke:#4678b8,color:#14233d
    classDef agent fill:#e7f7ef,stroke:#36865f,color:#123a26
    classDef host fill:#fff4d9,stroke:#ab7420,color:#513500
    classDef private fill:#f8e8ed,stroke:#a24a66,color:#4f1727
    classDef artifact fill:#f2f2f2,stroke:#666,color:#202020
    classDef outcome fill:#f3e9ff,stroke:#7851a9,color:#331b52

    source["assets/&lt;TYPE&gt;/&lt;ID&gt;.md<br/>Source description"]:::input
    taxonomy["standards/taxonomy.json<br/>Classification standard"]:::input

    source --> eligibility{"Builder source-fidelity<br/>screen"}:::agent
    eligibility -- "Not an actionable, faithful<br/>misconfiguration task" --> ineligible["Result: outcome = ineligible<br/>No build or retry"]:::outcome
    eligibility -- eligible --> builder["Builder agent (OpenHands)<br/>Generate instance contract, build overlays,<br/>harnesses, metadata, and gold patch"]:::agent
    taxonomy --> builder

    builder --> preflight["Host preflight<br/>Schema, required files, patch scope,<br/>shell syntax, evaluator safety"]:::host
    preflight -- failed --> correction["Host feedback + Builder correction<br/>Bounded build attempts"]:::host
    correction --> builder

    preflight -- passed --> build["Host Docker build<br/>Clean base image + faulty instance image"]:::host
    build --> validation["Host validation<br/>Reproduction succeeds; F2P fails;<br/>P2P and reference evaluation pass"]:::host
    validation -- failed --> correction
    validation -- passed --> instance["Validated instance<br/>instances/&lt;TYPE&gt;/&lt;ID&gt;<br/>and case image"]:::artifact

    instance --> verifier["Verifier (deterministic)<br/>Replay reproduction and reference evaluation"]:::host
    verifier --> publication["Optional publication<br/>Docker registry / Hugging Face dataset"]:::artifact

    subgraph diagnosis [Diagnosis evaluation]
        direction TB
        diagnosis_task["Public diagnosis prompt"]:::input
        diagnosis_runtime["Fresh faulty container<br/>unprivileged diagnostic shell"]:::artifact
        diagnosis_agent["Diagnosis evaluator agent (OpenHands)<br/>Rank root-cause candidates"]:::agent
        diagnosis_output["Structured diagnosis JSON"]:::artifact
        diagnosis_oracle["Private taxonomy and targets"]:::private
        diagnosis_scorer["Deterministic scorer<br/>Macro-F1, Hit@K, MRR, MAP, Joint@K"]:::private
        diagnosis_task --> diagnosis_agent
        diagnosis_runtime --> diagnosis_agent
        diagnosis_agent --> diagnosis_output --> diagnosis_scorer
        diagnosis_oracle --> diagnosis_scorer
        diagnosis_scorer --> diagnosis_result["Diagnosis metrics"]:::outcome
    end

    subgraph repair [Repair and hidden evaluation]
        direction TB
        task["Public task prompt<br/>from description"]:::input
        runtime["Faulty case container<br/>controlled tool session"]:::artifact
        fixer["Fixer agent (OpenHands)<br/>Investigate and repair"]:::agent
        task --> fixer
        runtime --> fixer
        fixer --> export["Export only allowed configuration paths<br/>as prediction.diff"]:::host

        oracle["Private oracle<br/>metadata, gold patch, F2P/P2P harnesses"]:::private
        evaluator["Private evaluator on a fresh faulty baseline<br/>Check patch scope, apply patch, run F2P/P2P"]:::private
        export --> evaluator
        oracle --> evaluator
        evaluator --> result["Structured pass / fail result"]:::outcome
    end

    instance --> runtime
    instance --> task
    instance --> diagnosis_task
    instance --> diagnosis_runtime
```

## Responsibilities and visibility

| Stage | Main responsibility | Inputs visible to the stage | Output |
| --- | --- | --- | --- |
| Builder | Turn a numbered source description into a runnable case. | Source description and taxonomy. | Instance files, Docker definitions, harnesses, metadata, and reference patch. |
| Host validation | Reject malformed or non-deterministic generated instances before they become cases. | Complete generated workspace. | Build/validation feedback or a validated instance. |
| Verifier | Independently replay the failure and reference repair. It is deterministic, not an LLM agent. | Existing image and private validation harnesses. | Reproducibility evidence. |
| Diagnosis evaluator | Produce a ranked root-cause classification and localization prediction without making repairs. | Public task and a fresh, unprivileged diagnostic container. | Structured diagnosis and token usage. |
| Diagnosis scorer | Compare the structured prediction with hidden taxonomy and target annotations. | Diagnosis JSON and private metadata. | F1, Hit@K, MRR, MAP@5, and Joint@K metrics. |
| Fixer | Diagnose and repair the faulty container using only the public task and allowed tools. | Public task and the faulty runtime. | `prediction.diff` exported from permitted paths. |
| Private evaluator | Score a submitted repair on a new faulty baseline. | Prediction patch plus hidden oracle artifacts. | F2P/P2P-based pass or failure record. |

Run artifacts are written under `runs/`, structured failures under `logs/`, and
per-case console captures under `logs/console/`. The fixer never receives the
private metadata, reference patch, or hidden harnesses.
