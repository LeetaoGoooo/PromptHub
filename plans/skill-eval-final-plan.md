# PromptHub Skill Evaluation Final Plan

Status: Draft for review
Owner: PromptHub
Scope: Skill evaluation mechanism upgrade

## 1. Document purpose

This document is the final solution draft for PromptHub skill evaluation.

It is intended for three steps only:

1. Internal consolidation of the final direction.
2. Independent review by Sonnet 4.6.
3. User review of content and layout before implementation task breakdown.

This document is not yet the execution backlog. Task decomposition into concrete work items should happen only after approval of this draft.

## 2. Goal

PromptHub should evaluate skills across two different layers:

1. Health audit: Can the skill be installed, discovered, trusted, and structurally understood?
2. Behavior evaluation: Does the skill actually perform correctly on defined tasks and constraints?

The target outcome is a PromptHub-native evaluation system that keeps the current audit model and adds a new scenario-based evaluation layer informed by two separate references:

1. Microsoft's `vscode-chat-customizations-evaluation` static authoring diagnostics.
2. Waza's suite, task, grader, and results model for scenario evaluation.

## 3. Completed foundation

The following pieces are already in place and should be treated as completed foundation rather than re-opened design work:

### 3.1 Package-first skill pipeline

- Skill installs are package-aware for local folders and remote multi-file skills.
- App-to-CLI bridge exports directory-format skill packages to `~/.prompthub` with markdown fallback.
- PromptHubCLI can install exported package directories, not just single markdown files.

### 3.2 Multi-project and workspace support

- Multiple saved project roots are supported.
- One active project root can be switched from the skill surfaces.
- Installed skill state is now tied to project-aware paths rather than a single implicit workspace.

### 3.3 Existing audit model

PromptHub already has a working audit stack centered around:

- agent visibility
- source integrity
- structural effectiveness

Current app-side orchestration exists in `SkillWorkspaceService`, and current effectiveness checks live in `PromptHubSkillKit` as structural and textual heuristics.

### 3.4 Validation baseline

- App-side bridge tests exist.
- Clean-shell validation scripts exist and pass.
- Current build and targeted test validation have a trustworthy execution path.

## 4. Final solution

### 4.1 Product position

PromptHub should not replace the existing audit system.

Instead, PromptHub should adopt a two-layer model:

1. Audit layer: visibility, integrity, package health, structural completeness.
2. Evaluation layer: scenario tasks, deterministic graders, recorded results, regression comparison.

This means PromptHub's current `effectiveness` naming is no longer enough by itself. Structurally valid does not mean behaviorally proven.

### 4.2 What to borrow, and from where

PromptHub should borrow the evaluation model, not the VS Code extension shell.

There are two distinct reference systems here and they should not be conflated:

- Microsoft repo: static, LLM-assisted analysis of prompt or instruction quality inside a VS Code workflow.
- Waza: scenario-based evaluation driven by `eval.yaml`, task files, grader types, and result artifacts.

PromptHub v1 should not claim full Waza compatibility.

Instead, PromptHub should implement a Waza-aligned subset with PromptHub-native packaging and execution boundaries. If future interoperability becomes important, an adapter can be added later.

The useful parts to absorb are:

- from Waza: suite-based evaluation definitions, task-oriented test cases, grader-based pass or fail logic, and machine-readable result artifacts
- from Microsoft: optional authoring diagnostics for ambiguity, contradiction, missing examples, or unclear tool guidance

The parts that should not be copied directly are:

- VS Code specific editor integration
- Problems panel driven workflow
- extension-command UX assumptions

### 4.3 Target architecture

The final architecture should contain five distinct layers.

#### Layer A. Installation and trust audit

Purpose:
Keep the current checks that answer whether a skill can be discovered, whether it matches its source, and whether the package is present in the expected place.

Status:
Mostly completed and already present.

#### Layer B. Structural skill audit

Purpose:
Keep structural checks on `SKILL.md`, examples, frontmatter, references, and body completeness.

Status:
Already present, but should be renamed or presented as structural quality rather than broad effectiveness.

#### Layer C. Evaluation suite inside the skill package

Purpose:
Add a package-local evaluation definition so that each skill can ship its own testable expectations.

Target convention:

- skill package continues to be the unit of install and export
- evaluation assets live beside the skill content in the package
- the evaluation suite is versioned with the skill itself

This is an intentional divergence from Waza's default layout. Waza typically locates evaluation files outside the skill directory under a separate `evals/<skill-name>/...` tree. PromptHub should keep evaluation assets inside the skill package because package portability and app-to-CLI portability matter more here than layout parity.

Suggested package layout:

```text
MySkill/
  SKILL.md
  prompt.md
  scripts/
  eval/
    eval.yaml
    tasks/
      should-trigger.yaml
      should-produce-json.yaml
    fixtures/
```

#### Layer D. Evaluation runner and graders

Purpose:
Run repeatable scenario checks against a skill and emit stable results.

Runner ownership decision for v1:

- `PromptHubSkillKit` owns evaluation suite discovery, schema parsing, result models, and the first deterministic runner.
- The app invokes that runner directly.
- `PromptHubCLI` may expose the same capability later, but it is not the source of truth for phase-one evaluation.

Executor model decision for v1:

- v1 evaluation is local and deterministic.
- v1 does not execute a live AI model or agent runtime.
- v1 evaluates declared inputs, fixtures, expected outputs, generated files, JSON payloads, and validator commands.
- live inference, trigger tracing, and tool-trace-based grading are deferred to a later phase.

First-class grader types for the first implementation:

- text contains or exact match
- JSON schema validation
- file exists or file diff check
- validator program exit status

These grader types are intentionally aligned with Waza's vocabulary, but PromptHub v1 uses a PromptHub-native subset rather than promising full `eval.yaml` compatibility.

Deferred grader types:

- LLM judge based grading
- cross-model ranking or subjective preference grading
- trigger and tool-trace-based grading

#### Layer E. Evaluation result persistence and UI

Purpose:
Store evaluation runs and make them visible in both drafting and installed-skill flows.

Required behavior:

- persist latest run result per skill version
- keep history for comparison
- distinguish clearly between not evaluated, failed, and passed
- show environment metadata for trust and reproducibility

## 5. UX rules

The UI should expose audit and evaluation as separate concepts.

Recommended presentation:

- Audit: installation, visibility, source, structure
- Evaluation: task suite status, last run time, pass rate, failing cases

PromptHub should not collapse these into a single opaque score in the first release.

Recommended labels:

- Audit status
- Structural quality
- Behavior evaluation
- Evaluation coverage

## 6. Delivery phases after approval

These are implementation phases, not yet the final execution backlog.

### Phase 1. Normalize the current model

Deliverables:

- rename or reposition current `effectiveness` language to structural quality
- keep current audit flow intact
- define the final data model boundary between audit and evaluation

Exit criteria:

- no user-facing ambiguity between structural validity and behavioral proof

### Phase 2. Add evaluation suite packaging

Deliverables:

- evaluation directory convention inside skill packages
- `eval.yaml` schema
- minimal task file schema
- package read and validation support in `PromptHubSkillKit`

Exit criteria:

- PromptHub can discover, parse, and schema-validate an evaluation suite in a skill package, and surface a clear error when the suite is malformed

### Phase 3. Build the local runner and deterministic graders

Deliverables:

- local run engine for evaluation suites
- core grader set
- result JSON format
- failure reporting model

Prerequisite:

- runner ownership and executor model are already fixed in this document for v1, so Phase 3 is scoped around deterministic local evaluation only

Exit criteria:

- at least one real skill can be evaluated end-to-end with repeatable output

### Phase 4. Surface evaluation in the app

Deliverables:

- draft-side evaluation panel
- installed-skill evaluation panel
- cached latest result and run history
- clear pass, fail, and not-run states

Exit criteria:

- users can run, inspect, and compare evaluations from PromptHub without leaving the app

### Phase 5. Add authoring diagnostics

Deliverables:

- optional instruction quality analysis during drafting
- warnings for ambiguity, conflict, missing examples, or unclear tool guidance

Exit criteria:

- PromptHub can help authors improve skills before running scenario evaluation

Sequencing note:

This is intentionally after the first behavior-evaluation release. PromptHub already has basic structural checks today, while the larger trust gap is missing behavioral proof. Phase 5 extends author guidance after the deterministic evaluation layer is in place.

### Phase 6. Introduce publish and recommendation hooks

Deliverables:

- mark evaluation-backed skills in store or library views
- optionally gate publish or recommendation flows on evaluation state

Exit criteria:

- behavior validation becomes a product-level trust signal, not just a hidden developer tool

## 7. Explicit non-goals for the first implementation

The first implementation should not try to do all of the following:

- build a VS Code-style extension workflow inside PromptHub
- require every imported third-party skill to have an evaluation suite
- use LLM grading as the primary truth source
- turn evaluation into a mandatory install-time blocker
- collapse every signal into one score

## 8. Acceptance standard for the final mechanism

The solution should only be considered complete when all of the following are true:

1. Existing audit behavior still works for installed skills.
2. A skill package can optionally include a local evaluation suite.
3. PromptHub can run deterministic evaluation tasks and persist the result.
4. The app clearly separates audit health from behavior proof.
5. Users can inspect why a skill passed or failed, not just see a badge.
6. The model supports future LLM diagnostics without depending on them.

## 9. Pending review questions

These questions should be explicitly confirmed during review before detailed implementation task breakdown:

1. Should evaluation assets always live inside the skill package, or can they be external for community packs?
2. Should publish recommendations use binary pass or fail, or coverage plus pass rate?
3. Which environments count as trustworthy for recorded runs: app-local only, CLI-local, or CI as well?

Resolved before implementation planning:

- v1 runner ownership: `PromptHubSkillKit`
- v1 executor model: deterministic local evaluation without live model invocation
- v1 compatibility stance: Waza-aligned subset, not full Waza compatibility

## 10. Next step after approval

Once this document is approved, the next step is to decompose it into concrete execution tasks with owners, dependencies, acceptance checks, and validation commands.