# Content schema status

No investigation content schemas are implemented yet. Examples in
MASTER_BUILD_SPEC.md describe the intended contracts, not validated runtime data.
Read WORLD_AND_SCENARIO_BIBLE.md before authoring scenario content.

Runtime game/config/game.json contains:
- claude_model: configurable model identifier requested by the specification.
- language: default dialogue language (`es`).
- dev_flags: development logging and offline defaults.

The identifier was checked against official model documentation; account access has not
been verified with a live call. Never include API keys in configuration or saves.

Future content must use stable IDs and deterministic prerequisites. NPC knowledge,
beliefs, secrets and proposals must stay separate from canonical evidence.

## Prototype terrain

game/content/world/prototype.json contains a legend (single-character symbols to
terrain names) and 20 rows of 20 symbols. Layout is authored; the locations array adds prototype POIs. Traversal costs remain deterministic in world_state.gd.

Each locations entry has id, name, kind (inn or monastery), position [x,y], and a
Spanish description. IDs LOC01/LOC11 and names match WORLD_AND_SCENARIO_BIBLE.md.
Positions are local to the 20x20 fixture, not the 160x120 campaign. Descriptions use
public location information only; no secret facts, clue unlocks or quest logic.

## Authored dialogue fixture

`game/content/dialogue/authored.json` is keyed by location ID. Each record contains
npc_id, name, greeting, hint, ordered branches (keywords array plus reply), and fallback.
Keywords are lowercase and accent-normalized. This is a prototype conversation format,
not the complete NPC knowledge/belief/secret schema. No reply carries unlock proposals.
Lucio's identity/public background comes from bible sections 10.2 and 13.1; the unnamed
innkeeper is a supporting prototype role, not the protagonist Mateo de Aranda. Directions
are local to the prototype map. Conversations do not perform purchases yet.

## Language tag convention

successful_grammar entries use the fixed grammar IDs in LearnerProfile.GRAMMAR or
verb:<infinitive> from LearnerProfile.VERBS. Error type may combine those with |.
Unknown labels are ignored for mastery; correction text can still be shown after schema
validation. No new response fields or evaluation requests were added. Learner values
are observed estimates initialized at zero; persistence and placement are future work.

## Reserved side investigation catalog

game/content/scenario/side_investigations.json is version 1, authored_not_integrated.
Arrays: curriculum_blocks, units, branches, quests, artifacts, battles, cross_branch_links;
abilities is keyed by ability ID. Runtime loaders do not consume this file yet.
SX001-SX108 reference AX001-AX108 and BX001-BX108; SB01-SB12 group nine quests each.
Original SQ identifiers are unchanged. requires is an all-of dependency list.
Each puzzle stores three interpretations, answer/rejection IDs and required evidence.
Twelve access_puzzle entries additionally store self-contained acrostic rules/answers.
These author-side solutions must not be shown in future player-facing clue views.

Language records specify prerequisite block, new target, authored prompt, model frame,
independent production and delayed recall. These are requirements, not an implemented
assessment engine. Battle victory has null truth_effect; peaceful access requires only
prior evidence, never its own reward. Artifacts are nonconsumable and quest-critical.
The validator scene tests references, DAG reachability, language order, answer coherence,
cipher solutions, stack bounds and non-blocking retreat/peaceful paths.
