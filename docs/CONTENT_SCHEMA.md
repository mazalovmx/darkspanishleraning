# Content schema status

No investigation content schemas are implemented yet. Examples in
MASTER_BUILD_SPEC.md describe the intended contracts, not validated runtime data.
Read WORLD_AND_SCENARIO_BIBLE.md before authoring scenario content.

The initial root configuration contains:
- claude_model: configurable model identifier requested by the specification.
- language: default dialogue language (`es`).
- dev_flags: development logging and offline defaults.

The model identifier has not been checked against the live API. Validate availability
when implementing Epic 5. Never include API keys in configuration or saves.

Future content must use stable IDs and deterministic prerequisites. NPC knowledge,
beliefs, secrets and proposals must stay separate from canonical evidence.
