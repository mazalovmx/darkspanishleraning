# Implementation rules

You are the sole implementation agent for this repository.

Primary objectives:

1. Keep the codebase small.
2. Prefer Godot built-ins over new dependencies.
3. Prefer JSON content over custom logic.
4. Avoid speculative abstractions.
5. Do not refactor working systems unless required by the current task.
6. One normal task should touch fewer than five implementation files.
7. Every task must have explicit acceptance criteria.
8. Run relevant tests before finishing a task.
9. Update docs/STATE.md after every completed task.
10. Make one coherent commit per task.
11. Never allow Claude output to mutate canonical game state without deterministic validation.
12. Optimize for a weak Windows PC.
13. Prefer readability over flexibility.
14. Do not generalize for multiplayer, modding, commercial distribution, mobile, consoles, or web.
15. Do not implement a feature before its current epic is unlocked.

Before each task:
- read docs/MASTER_BUILD_SPEC.md
- read docs/STATE.md
- inspect relevant existing files
- restate the acceptance criteria internally

After each task:
- run tests
- launch the smallest relevant Godot test scene
- update STATE.md
- commit

If a requested implementation becomes substantially more complex than the specification:
- implement the smallest compliant version
- document the limitation
- do not invent a new architecture.
