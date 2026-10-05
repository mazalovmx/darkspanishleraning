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

## NPC grounding boundary

npc_grounding.json contains facts keyed by ID, clues keyed by the same ID, an authored
intent-keyword map and NPC profiles keyed by ID. Profiles require persona, knowledge,
beliefs, false_beliefs, secrets, lie_policy and language_register. A clue policy requires
intent and prerequisites (exact string-valued quest states); a secret entry requires id
and nonempty prerequisites. No clue entries are populated at this stage.

Only authorized known facts and disclosed secrets reach the prompt. Beliefs stay in
separate fields and never grant clue permission. Syntax validation accepts null or
nonempty unlock strings up to 100 characters; NpcGrounding then rejects IDs outside
the canonical catalog/knowledge or unmet conditions. This service is read-only.
The dialogue supplies empty quest/reveal state until persistence/evidence integration;
neither model text nor conversation.player_intent supplies canonical state.

## Equipment and ghost catalogs (authoring only)

equipment.json reserves EQ001-EQ150 (ordinary variants), SP001-SP024 (unique parts),
SA01-SA06 (assembled items/recipes). Thirty types map to fourteen slots through ring
and misc slot groups. Every stat has an explicit cap. All six highest-rank items are
soul-assembly rewards, never shop stock. reward_bindings reference SX quests; they are
future overlays, not mutations of the original quest/evidence catalog.

Recipes bind exact part IDs to slots, memory sources to components and soul tasks to
curriculum blocks. Persist consent by hero/set and retain exact component instances.
The catalog's assembly/economy rules are requirements for a future local verifier.

ghost_knights.json reserves NK01-NK08 and defines eight reversible local effect types.
Profiles reference SB branches, optional SA counters and existing battle unit IDs.
They include exact first/second-round commands and target rules, but no runtime AI
consumes them. turn_contract specifies atomic snapshot/order resolution and save fields.
Immutable evidence and main story facts are outside every intervention's authority.
