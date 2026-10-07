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

game/content/scenario/side_investigations.json is version 1, runtime_integrated_unbalanced.
Arrays: curriculum_blocks, units, branches, quests, artifacts, battles, cross_branch_links;
abilities is keyed by ability ID. `game/src/world/side_investigations.gd` loads it;
cross_branch_links and outcome flags are not consumed yet.
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

## Conversations (authored.json)

Keys are a location id, or any id with `location_id` naming the location for an
additional speaker there. Fields: npc_id, name, greeting, greeting_again, hint,
branches (keywords + reply), fallback. Optional gates, both checked when the
conversation is listed, opened and submitted to:
- `requires`: a campaign node id that must already be recorded.
- `companion_hero`: a hero id; that hero must be unlocked, on the same cell at this
  location and not the active hero (a hero cannot interview themself).

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

content/spanish/soul_rituals.json holds the Spanish of each soul conversation: the
model per stage, `alternatives` (understood near-misses that receive a "Forma
sugerida") and `keys`. `keys.<stage>` is a list of needs `{"need": label, "any":
[forms]}`; a free answer passes when, for every need, it contains one of the forms as
whole words (lower case, accents ignored). The label is shown when a need is missing,
so it describes the form without giving the answer. Listening uses keys in code;
consent has none and stays exact. Every model must meet its own keys
(equipment_state_test checks this).

content/scenario/campaign.json nodes use the same `keys` format. A conclusion is
accepted when it equals an answer or variant, or when it meets every need, is a single
sentence, is at most eight words longer than the longest authored version and has the
same polarity (negated or not) as the first answer, unless the variants themselves mix
polarity. Labels name a role or a form ("quién lo hizo", "matar en pretérito"), never
the solution. `council_resolution` has no keys: the player types one of the shown
proposals exactly. campaign_test checks that every answer and variant meets its keys.

ghost_knights.json reserves NK01-NK08 and defines eight reversible local effect types.
Profiles reference SB branches, optional SA counters and existing battle unit IDs.
They include exact first/second-round commands and target rules, but no runtime AI
consumes them. turn_contract specifies atomic snapshot/order resolution and save fields.
Immutable evidence and main story facts are outside every intervention's authority.

## Prototype save format v1

user://savegame.json has exactly version, map_id, day, hero, explored and learner.
hero contains cell [x,y] and movement; explored is a unique list of in-bounds cell pairs.
Current map_id is prototype_20x20_v1; incompatible map changes require a version/map
migration decision. The file is bounded to 1 MiB. Unknown formats are not silently reset.

learner contains block, grammar, verbs, errors, vocabulary, recent_messages and
successful_contexts. Fixed grammar/verb categories and ranges are validated; error
records have positive integer count, valid last_seen_day and up to three examples.
Only implemented NPC contexts/current teaching block are accepted. Vocabulary is capped
at 100, message fingerprints at 40; these are learner memory, not full dialogue history.

Visibility, terrain and AStar grids are derived. Save decoding constructs a separate
WorldState; failed decoding cannot partially mutate the current session. A staged,
validated file replaces the old slot only after successful writing. A stale .tmp is
not treated as a committed save. No investigation/inventory placeholders are fabricated.

## Evidence seed and save v2

content/evidence/opening.json owns canonical observation/claim/interpretation/status/
causal text. EvidenceGraph stores only progress, returns copies and accepts the authored
Spanish exercise plus classification. A record has found_day, classification and
spanish_note; no model or save can replace canonical node text.

Save v2 adds evidence to the six v1 fields. V1 migration supplies an empty dictionary;
the next write uses v2. Accepted records use known IDs, exact authored classification,
bounded guided Spanish and an integer day no later than the saved world day.
This is the first graph node; hypothesis links/comparison gates remain later work.

## Dialogue disclosure

monastery_claim is a testimony node whose classification is claim and whose source is
Lucio reporting the community's position. NPC grounding grants him this clue with
ask_death intent and food_recorded=yes prerequisite. context_flags derives that flag
from canonical evidence rather than model text; no arbitrary quest flags are introduced.

Dialogue captures eligible IDs when sending and rechecks when the response arrives.
EvidenceGraph.record_dialogue validates source/location, local intent, prerequisite,
repeat status and authored question. Physical record() cannot grant testimony.
Critical claim text comes from opening.json. Save restore also enforces the food
prerequisite and discovery chronology; no schema bump beyond v2 is needed.

## Institutional acts (institutions.json)

`content/scenario/institutions.json` lists authorities (with the kinds of act each may
perform), procedures (required seal, whether a witness is required) and kind labels.
A campaign node's `declaration`, or a decision outcome's `declaration`, is an act:
`{kind, authority, procedure, target, seal, witness, effect, text}`. `institutions.gd`
accepts it only when the authority holds that kind, the seal matches the procedure,
a required witness is named and target/effect/text are present. Valid acts of recorded
nodes and chosen outcomes are in force (`campaign_state.acts/effects`); their `effect`
flags are the world consequences. An outcome may list `closed_by` effects that make it
unavailable. Acts are derived from campaign records, so they add no save state.

Decision nodes (`"decision": true`) are chosen, not classified: the journal hides the
category and any category is ignored. Their `outcomes` may carry `effect` (a
consequence flag), `income` (daily resources added by the strategy economy) or a
`declaration`. A node's `closed_by` lists effects that make it unavailable; the council
resolution's `epilogues` map effects to lines appended to the ending.
