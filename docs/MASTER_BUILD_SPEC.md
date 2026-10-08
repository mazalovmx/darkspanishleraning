# MASTER BUILD SPEC — Single-Player Spanish Investigation Strategy RPG

**Status:** Source of truth for Copilot Agent implementation  
**Target user:** one player, local Windows machine, weak hardware  
**Development model:** Copilot Agent implements the project end-to-end  
**Runtime AI:** Claude API only for NPC conversation + Spanish evaluation  
**Engine:** Godot 4.6.2  
**Base project:** `gdquest-demos/godot-open-rpg`  
**Primary language:** GDScript  
**Project type:** 2D / pseudo-isometric / turn-based / investigation RPG-strategy  
**Target playtime:** 4–5h critical path, 8–10h full content  
**Distribution:** local Windows executable only  

---

# 0. Executive decision

Use **Godot 4.6.2** with **GDQuest Open RPG** as the starting codebase.

Do **not** use VCMI, fheroes2, Wesnoth, Unity, Unreal, Electron, Python game frameworks, a local LLM, or a custom engine.

Why:

1. Godot is free and open source under MIT.
2. GDQuest Open RPG is MIT-licensed and already includes:
   - turn-based combat,
   - inventory,
   - maps,
   - dialogue infrastructure,
   - grid movement,
   - UI,
   - character progression.
3. GDScript is much easier for Copilot Agent to modify safely than a large C++ engine.
4. Godot has built-in HTTP support, so Claude can be called without a backend.
5. Godot runs well on weak Windows hardware in a simple 2D project.
6. The game is private and single-user, so there is no need for servers, authentication, multiplayer, anti-cheat, cloud state, telemetry backend, or commercial-grade content pipelines.

The implementation goal is **not to reproduce Heroes III technically**.

Heroes III is the mechanical reference for exploration, economy, armies and equipment, as clarified by the user on 2026-10-05. Implement these rules incrementally in Godot under the existing gates; using another engine or copying its technical architecture is not required.

The required gameplay includes:

- large map,
- fog of war,
- hero movement,
- roads and terrain costs,
- locations and resources,
- armies/stacks,
- turn-based battles on a hex battlefield with movement, as in Heroes III,
- switching between three heroes,
- strong scenario progression,
- text-heavy investigation.

The project must remain small enough that Copilot can understand the whole architecture from repository documentation.

---

# 1. Product pillars

## 1.1 Investigation first

The central gameplay is not combat.

The player:

1. explores;
2. notices signs;
3. talks to people;
4. separates observation from interpretation;
5. tests hypotheses;
6. collects institutional documents;
7. decides what counts as evidence;
8. acts.

Combat exists to create pressure and consequences.

---

## 1.2 Spanish is the control surface

Spanish is not a minigame.

The player uses Spanish to:

- buy food;
- ask prices;
- request directions;
- interrogate witnesses;
- persuade officials;
- complain about incorrect goods;
- ask for permission;
- understand warnings;
- reconstruct timelines;
- challenge contradictions;
- formulate hypotheses;
- issue conclusions.

The game should force small Spanish production events every 5–10 minutes outside combat.
User clarification (2026-10-05): Spanish conversation and intensive language practice
are core gameplay. Every purchase and most quests must require active Spanish
production and meaningful practice, rather than optional dialogue decoration or a
click-only bypass. Build this through the scheduled dialogue, evaluation and
transactional-language stages; authored offline branches must preserve practice
without making an API response a progression gate. Keep feedback concise and in
context as required by the feedback policy.

---

## 1.3 Language gets harder through interaction, not levels

Every conversation has five difficulty axes:

```text
grammar
lexicon
sentence_length
implicit_meaning
interaction_pressure
```

Difficulty increases gradually.

The game must not simply switch from “A2” to “B1”.
### Ordered curriculum (user clarification, 2026-10-05)

Use a sequential syllabus, not random jumps between easy and advanced tasks:
1. Consolidate present tense, ser/estar/hay, agreement and basic questions.
2. Present-tense needs, quantities, prices, requests and directions in transactions.
3. Completed past events: preterite, frequent irregular verbs and simple timelines.
4. Past descriptions and habits: imperfect, then preterite/imperfect contrast.
5. Connected accounts: object pronouns, por/para, relative clauses and reported facts.
6. Plans and experience: ir a + infinitive, future and present perfect in context.
7. Hypotheses and argument: conditional, basic subjunctive and reported speech.

Each block follows introduction with a model, supported production, independent use,
and delayed recall. Require repeated success across multiple contexts before advancing;
a single correct answer or a story level is not proof of mastery. Choose exact mastery
thresholds when implementing learner evaluation/scheduling, and test them deterministically.
Quest complexity and linguistic prerequisites must be aligned: scaffold a required story
scene if the learner has not mastered its language yet. Do not make API availability a gate.

Adapt the five difficulty dimensions within the current block first. Reviews target
already taught material; stretch tasks use only the nearest next block with support.
The 60/25/15 scheduler is subordinate to this prerequisite order: no arbitrary advanced
tense before its prerequisites. Early consolidation can reduce the stretch share.
Introduce at most one new grammar/tense target per encounter, revisit it in several
purchases or quests, and keep a clear current learning objective for the player.
This sequence is the game's chosen syllabus, not a claim that all courses share one order.

Player level (user clarification, 2026-10-07): the player is at about B1 but has not
studied grammar for a long time. Keep the ordered review of every block, but make the
content of each task suitable for B1 from the first block: natural sentence length and
vocabulary, meaningful investigative content, no trivial copying. Every grammar point
comes with a short rule reminder, shown when the form is introduced and available
again during independent practice and after an error. The ordered sequence is a
structured refresher for this player, not a beginner course.

Conversation and orthography (user clarification, 2026-10-07): add as many Claude
conversations as possible, so that the game is played by typing Spanish to characters
and never reduces to choosing the right answer. In every block except the last,
ignore errors that concern only written accents (tildes), the diaeresis (ü) or
apostrophes; in the last block (conditions, subjunctive and argument) they count.
Grammar and the naturalness of the exchange are still evaluated at every level: in
conversations by Claude's assessment, deterministically wherever a task gates progress.

---

## 1.4 Canonical world is deterministic

Claude is never the source of truth.

Core invariant:

```text
LLM proposes
→ deterministic code verifies
→ deterministic game state changes
```

Claude may:

- phrase dialogue;
- lie in character;
- speculate;
- evaluate Spanish;
- classify player intent;
- suggest which known clue the player appears to be asking about.

Claude may **not**:

- create canonical clues;
- create new murders;
- create new locations;
- unlock quests directly;
- change inventory;
- change relationships directly;
- decide battle outcomes;
- create official world state.

---

## 1.5 Dark world, not torture spectacle

The world is dark because systems produce harm.

Examples:

```text
grain shortage
→ official price control
→ legal supply disappears
→ black market expands
→ enforcement increases
→ supply falls further
→ hunger grows
```

or:

```text
danger prediction
→ district restricted
→ economic decline
→ unrest
→ model sees unrest
→ restrictions increase
```

Moral darkness should emerge from incentives, authority, institutional inertia, misinterpretation and survival.

---

# 2. Philosophical / semiotic core

The game must repeatedly teach through mechanics:

```text
signal ≠ meaning ≠ cause ≠ action
```

A footprint can mean:

- murderer;
- witness;
- guard;
- frightened servant;
- staged evidence;
- ordinary traffic.

A statement can be:

- observation;
- inference;
- rumor;
- accusation;
- promise;
- order;
- confession;
- institutional declaration.

A signed declaration may alter the game world more strongly than a physical object.

## 2.1 Speech-act model

Track relevant statements as:

```text
locution
illocution
authority
felicity_conditions
perlocution
world_effect
```

Example:

```text
"The bishop declares Tomás excommunicated."
```

This is not merely information.

If valid authority and procedure exist, it changes:

- shelter rules;
- trade access;
- guard behavior;
- testimony incentives.

---

# 3. Technology stack

## 3.1 Required

```text
Godot 4.6.2
GDScript
JSON
Git
VS Code / GitHub Copilot Agent
Claude Messages API
```

## 3.2 Base repository

Use:

```text
https://github.com/gdquest-demos/godot-open-rpg
```

Reuse only what is useful.

Expected reusable areas:

```text
combat/
overworld/
src/
dialogue infrastructure
inventory
UI
save-related patterns
```

Delete demo-specific content.

## 3.3 Do not introduce

Do not add unless absolutely necessary:

```text
Node.js
Python runtime
Docker
SQLite
PostgreSQL
Redis
React
C#
C++
custom networking
ECS framework
dependency injection framework
event sourcing framework
local inference model
```

Prefer Godot-native functionality.

---

# 4. Repository layout

Create:

```text
/game
    project.godot

/src
    core/
    world/
    heroes/
    battle/
    dialogue/
    claude/
    spanish/
    evidence/
    quests/
    ui/
    save/

/content
    world/
    heroes/
    units/
    npcs/
    locations/
    quests/
    evidence/
    dialogue/
    spanish/
    scenario/

/assets
    tiles/
    portraits/
    units/
    ui/
    audio/

/tests
    unit/
    integration/
    dialogue_golden/
    scenario/

/docs
    MASTER_BUILD_SPEC.md
    COPILOT.md
    ARCHITECTURE.md
    CONTENT_SCHEMA.md
    STATE.md
    BACKLOG.md
    TESTING.md
    CLAUDE_PROMPTS.md
```

---

# 5. Rules for Copilot Agent

Create `/docs/COPILOT.md` with these mandatory rules.

```text
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
```

---

# 6. Game architecture

```text
┌──────────────────────────────────────┐
│                GODOT                 │
│                                      │
│  World Map                           │
│  Heroes                              │
│  Battles                             │
│  Quests                              │
│  Inventory                           │
│  Evidence Graph                      │
│  NPC State                           │
│  Learner State                       │
│  Save/Load                           │
│                                      │
│              ↓                       │
│       Dialogue Orchestrator          │
│              ↓                       │
│        Claude API Client             │
└──────────────┬───────────────────────┘
               │
               ▼
        Claude Sonnet 5
               │
               ▼
     JSON proposal / evaluation
               │
               ▼
        Deterministic Verifier
               │
               ▼
           Game State
```

---

# 7. Global game state

Create a single authoritative `GameState`.

Example:

```json
{
  "version": 1,
  "day": 4,
  "active_hero": "inquisitor",

  "heroes": {},
  "world": {},
  "quests": {},
  "npc_states": {},
  "evidence": {},
  "learner": {},
  "flags": {}
}
```

No canonical world fact should exist only inside a scene node.

---

# 8. World map

## 8.1 Map scale

Initial production target:

```text
160 × 120 cells
```

Prototype:

```text
20 × 20 cells
```

Do not create the full map before the vertical slice works.

## 8.2 Rendering

Use:

```text
TileMap / TileMapLayer
Camera2D
Sprite2D
```

Pseudo-isometric visual style is sufficient.

True isometric projection is optional.

The map must prioritize clarity over graphical authenticity.

## 8.3 Terrain

Only:

```text
road
grass
forest
marsh
mountain
water
field
ruins
settlement
snow
```

Movement costs:

```text
road       1
grass      1
field      1
forest     2
marsh      3
ruins      2
snow       2
mountain   impassable
water      impassable
```

## 8.4 Pathfinding

Use Godot built-in:

```text
AStarGrid2D
```

Do not write a custom A* implementation.

## 8.5 Fog

Three states:

```text
UNKNOWN
EXPLORED
VISIBLE
```

Default view radius:

```text
5 cells
```

No line-of-sight simulation in MVP.

## 8.6 Turn loop

```text
player selects hero
→ choose destination
→ movement points consumed
→ trigger POI/event if reached
→ optional dialogue/battle/action
→ continue until no movement or player ends turn
→ world day advances when all heroes end turn
```

---

# 9. Three heroes

## 9.1 Inquisitor

Role:

```text
formal institutions
church
court
archives
official authority
```

Language profile:

```text
formal Spanish
requests
testimony
documents
reported speech
subjunctive
```

Army archetypes:

```text
novice
cleric
warden
hospitaler
templar-analogue
inquisitorial guard
```

Do not use trademarked or franchise-specific faction names.

---

## 9.2 Smuggler

Role:

```text
black market
criminal networks
merchants
workers
informal knowledge
```

Language profile:

```text
colloquial Spanish
prices
threats
negotiation
slang
short commands
```

Army archetypes:

```text
thief
smuggler
bandit
knife fighter
crossbow mercenary
saboteur
```

---

## 9.3 Survivor

Role:

```text
technology
systems
causality
history
institutional failure
```

Language profile:

```text
abstract vocabulary
conditionals
subjunctive
reported speech
causal reasoning
```

Army should be small.

Use a few rare units rather than a full faction.

---

# 10. Hero state

Example:

```json
{
  "id": "inquisitor",
  "position": [42, 71],
  "movement_max": 18,
  "movement_remaining": 18,
  "health": 100,
  "gold": 120,
  "inventory": [],
  "army": [],
  "quest_ids": [],
  "known_evidence": [],
  "relationships": {}
}
```

Hero switching:

```text
F1 = Inquisitor
F2 = Smuggler
F3 = Survivor
```

Also support portrait buttons.

---

# 11. Locations / POIs

Do not create explorable interiors unless essential.

Most interiors are modal UI.

Examples:

```text
inn
shop
monastery
court
checkpoint
farm
camp
ruins
mine
graveyard
hospital
warehouse
stable
```

Example JSON:

```json
{
  "id": "black_dog_inn",
  "position": [51, 33],
  "region": "west_road",
  "actions": [
    "talk_innkeeper",
    "buy_food",
    "rent_room",
    "ask_road"
  ]
}
```

---

# 12. Inventory / economy

Core strategic resources (Heroes III reference):

```text
gold
wood
ore
mercury
sulfur
crystal
gems
```

Resources are spendable strategic assets, not collectible decorations. They pay for:
- construction and upgrades of settlement buildings;
- recruiting army stacks and upgrading eligible troops;
- purchasing artifacts and other equipment;
- authored services and exchanges with explicit prices.

Buildings unlock recruitment, troop growth, upgrades or income. Owned mines generate
daily income and can be contested on the adventure map. Finite stock, recruitment
availability, ownership and the complete resource cost must be validated before an
atomic purchase; rejected or interrupted orders cannot spend resources or grant goods.
Travel budgets, roads, terrain, fog, resource sites and guarded rewards form the same
strategic loop as investigations. Target armies have seven stack slots; any smaller
early battle fixture is an explicitly temporary development slice.

Every purchase, including construction and recruitment, requires active Spanish:
name the desired building/unit/item, specify quantity where relevant, understand the
price and confirm the request. Use the current taught grammar block and an authored
offline route. Language retries do not advance hostile world turns or consume payment.
Never award mastery merely for selecting a menu item.

Food, medicine, horse feed and lamp oil remain optional authored supplies, distinct
from the seven strategic resources. They do not replace the core economy.
Implement resource/army/building runtime at the corresponding unlocked milestones;
these requirements do not claim those systems already exist. The user's simultaneous
ghost-knight world orders remain an explicit variation on the reference game's turns.

Quest items:

```text
letters
seals
keys
books
evidence objects
```

No grid inventory.

Use a plain list.

---

# 13. Battle system

Reuse the simplest turn-based battle system from Open RPG (its stat resource), on a
Heroes III-style battlefield.

User decision (2026-10-08): battles follow Heroes III, with stacks moving on a hex
battlefield. This replaces the earlier rule "Do not implement HoMM battlefield movement
in MVP" (it is no longer in force).

Represent armies as stacks.

Example:

```json
{
  "type": "militia",
  "count": 18,
  "hp_per_unit": 9,
  "damage_min": 2,
  "damage_max": 4,
  "initiative": 7,
  "speed": 4,
  "ability": "brace"
}
```

Maximum stacks per side:

```text
7
```

Battlefield:

```text
11 columns × 7 rows of pointy-top hexes, odd rows offset by half a hex
player stacks start in the first column, enemy stacks in the last, spread over the rows
1-4 obstacles (rocks or trees) in the middle columns, from the battle seed
the ground shows the adventure-map terrain where the battle happens
```

Turn order and movement:

```text
each round, living stacks act in initiative order (ties: stack index)
a stack moves up to its speed in hexes around obstacles and other stacks
flying stacks only need a free hex within their speed
dead stacks leave no obstacle
```

Commands:

```text
MOVE      walk to a reachable free hex; ends the stack's turn
ATTACK    melee: walk next to the target (from the chosen side if reachable) and strike;
          if no hex next to it is reachable, advance as close as possible instead
          ranged: shoot from anywhere; with an enemy adjacent, fight that enemy in melee
          at half damage
DEFEND
ABILITY   self abilities act at once; striking abilities follow the ATTACK rules and are
          not spent when the stack only advances
RETREAT
```

Melee strikes allow one retaliation per target per round; shots never draw retaliation.
A ranged stack retaliating in melee deals half damage.

Enemy AI:

```text
targets = player stacks it can hit this turn (shot, or a reachable hex next to them)
if targets:
    if lethal_attack_available among targets:
        use it
    else:
        attack lowest_effective_hp_target among targets
else:
    advance toward the nearest player stack
scripted encounters keep their authored target rule, limited to reachable targets
when there are any
```

No advanced tactical planner in MVP.

---

# 14. Evidence system

Create a `SemioticEvidenceGraph`.

Every evidence node may contain:

```json
{
  "id": "horse_sound",

  "observation": "Mateo says he heard a horse after midnight",
  "source": "mateo",
  "source_type": "testimony",

  "sign_type": "auditory_report",

  "actor": null,
  "intent": null,
  "authority": "none",

  "context": [
    "night",
    "near_monastery"
  ],

  "interpretations": [
    "someone arrived",
    "someone departed",
    "horse moved without rider"
  ],

  "confidence": 0.45,
  "causal_mechanism": null,
  "institutional_status": "unverified",
  "consequences": []
}
```

## 14.1 Required distinction

UI must visibly distinguish:

```text
OBSERVATION
CLAIM
INTERPRETATION
INSTITUTIONAL STATUS
CAUSAL LINK
```

## 14.2 Evidence gates

A quest gate must be able to require:

```text
evidence exists
AND
evidence classified correctly
AND
two interpretations compared
AND
one causal link established
```

Not merely:

```text
player found clue
```

---

# 15. Speech-act system

Statement categories:

```text
observation
inference
rumor
accusation
promise
order
confession
declaration
warning
request
threat
```

Institutional speech acts include:

```text
sentence
excommunication
permit
ban
appointment
dismissal
confiscation order
legal recognition
```

A valid institutional act requires:

```text
speaker authority
correct procedure
correct object/target
required witnesses/seal if applicable
```

Game-world changes occur only after these deterministic conditions are satisfied.

---

# 16. Claude integration

## 16.1 Model

Default:

```text
claude-sonnet-5-5
```

Keep model name in config:

```json
{
  "claude_model": "claude-sonnet-5-5"
}
```

Never hard-code the model in multiple files.

## 16.2 API use

Use Claude only for:

```text
NPC dialogue
Spanish evaluation
intent classification
implicit recast
conversation difficulty adaptation
conversation summarization
```

Do not use Claude for:

```text
pathfinding
quest logic
combat
inventory
evidence validation
world generation
save state
```

## 16.3 API key

Read from Windows environment:

```text
ANTHROPIC_API_KEY
```

Do not save it to repository or savegame.

## 16.4 Single-call policy

For each player message, make one request that returns:

```text
NPC reply
meaning evaluation
grammar evaluation
natural correction
grammar tags
vocabulary tags
intent
suggested known clue reference
attitude proposal
```

Avoid multiple model calls per turn.

---

# 17. Claude request schema

Input object assembled by Godot:

```json
{
  "npc": {},
  "scene": {},
  "npc_knowledge": [],
  "npc_beliefs": [],
  "npc_secrets": [],
  "relationship": {},
  "learner_profile": {},
  "focus_grammar": [],
  "focus_verbs": [],
  "recent_errors": [],
  "conversation_summary": "",
  "recent_dialogue": [],
  "player_message": ""
}
```

---

# 18. Claude response schema

Expected JSON:

```json
{
  "npc_reply": "string",

  "language": {
    "meaning_understood": true,
    "confidence": 0.0,

    "errors": [
      {
        "type": "preterite",
        "original": "yo veo ayer",
        "better": "yo vi ayer",
        "severity": "important"
      }
    ],

    "successful_grammar": [],
    "new_vocabulary": []
  },

  "conversation": {
    "player_intent": "ask_about_witness",
    "npc_attitude_delta": 0,
    "suggested_unlock": null,
    "difficulty_observation": "comfortable"
  }
}
```

The parser must reject malformed responses.

On failure:

```text
retry once
→ if still invalid, use authored fallback
```

---

# 19. Canonical validation

If Claude returns:

```json
"suggested_unlock": "horse_after_midnight"
```

the game checks:

```text
Does clue ID exist?
Does this NPC know it?
Has it already been revealed?
Does player intent match the clue?
Are prerequisite quest states true?
```

Only then:

```text
reveal clue
```

Never trust arbitrary IDs.

---

# 20. NPC model

Each NPC file:

```json
{
  "id": "mateo_innkeeper",

  "persona": {
    "age": 52,
    "occupation": "innkeeper",
    "traits": [
      "tired",
      "cynical",
      "observant"
    ],
    "goal": "avoid trouble"
  },

  "knowledge": [],
  "beliefs": [],
  "false_beliefs": [],
  "secrets": [],

  "lie_policy": {
    "can_lie": true,
    "triggers": []
  },

  "language_register": "neutral_colloquial"
}
```

---

# 21. NPC memory

Do not send whole chat history.

Store:

```json
{
  "conversation_count": 4,
  "relationship": 17,

  "player_reputation": "persistent but polite",

  "discussed_topics": [],
  "revealed": [],
  "lies_told": [],

  "summary": ""
}
```

Send:

```text
summary
+ latest 4–6 turns
+ current scene
```

Conversation summary can be generated by Claude only when history becomes long.

The summary itself must never introduce canonical facts not already present.

---

# 22. Claude system prompt

Use a stable prompt.

```xml
<role>
You are an NPC in a dark low-fantasy investigation game and,
separately, an invisible Spanish-language evaluator.

Inside npc_reply you must never behave like a language teacher.
</role>

<world_rules>
WORLD_FACTS are canonical.
NPC_KNOWLEDGE contains facts this NPC can know.
NPC_BELIEFS may be wrong.
NPC_SECRETS may be concealed.

Never invent canonical events, clues, locations, identities or causes.
If information is absent, the NPC does not know it.
</world_rules>

<npc_behavior>
Remain in character.

The NPC may:
- misunderstand,
- lie when motivated,
- evade,
- bargain,
- refuse,
- speculate,
- express uncertainty.

Separate knowledge from belief.
Do not reveal information merely because the player asks.
</npc_behavior>

<spanish>
The player is learning Spanish.

LANGUAGE_PROFILE defines target difficulty.

Adjust:
- grammar,
- vocabulary,
- sentence length,
- implicitness,
- interaction pressure.

If meaning is understandable, continue the conversation.
Correct no more than two important errors per turn.
Prefer implicit recasts inside npc_reply.
</spanish>

<progression>
Successive conversations should generally become harder.

Increase difficulty through:
1. grammar,
2. richer vocabulary,
3. longer clauses,
4. less explicit context,
5. pragmatic implication,
6. conflicting interpretations.

Do not increase all dimensions at once.
</progression>

<semiotics>
A statement is evidence about a person's belief or intention,
not automatic truth about the world.

When relevant distinguish:
observation,
inference,
rumor,
accusation,
promise,
order,
confession,
declaration.
</semiotics>

<output>
Return valid JSON only.
Follow RESPONSE_SCHEMA exactly.
</output>
```

---

# 23. Dynamic prompt block

Per turn append:

```xml
<npc>
...
</npc>

<npc_knowledge>
...
</npc_knowledge>

<npc_beliefs>
...
</npc_beliefs>

<npc_secrets>
...
</npc_secrets>

<scene>
...
</scene>

<language_profile>
...
</language_profile>

<focus_grammar>
...
</focus_grammar>

<focus_verbs>
...
</focus_verbs>

<recent_errors>
...
</recent_errors>

<conversation_summary>
...
</conversation_summary>

<recent_dialogue>
...
</recent_dialogue>

<player_message>
...
</player_message>
```

---

# 24. Conversation difficulty model

Store:

```json
{
  "grammar": 0.30,
  "lexicon": 0.35,
  "sentence_length": 0.20,
  "implicit_meaning": 0.10,
  "interaction_pressure": 0.10
}
```

Difficulty updates:

```text
3 successful exchanges:
    +0.05 to ONE weak dimension

2 serious comprehension failures:
    -0.04 to ONE pressure dimension

maximum change per conversation:
    ±0.10
```

Do not raise every dimension simultaneously.

---

# 25. Conversation tiers

## Tier 1 — Survival

NPC output:

```text
10–20 words
```

Grammar:

```text
ser
estar
hay
tener
querer
presente
articles
gender
```

Examples:

```text
¿Qué necesita?
¿Quiere pan o carne?
El camino del norte está cerrado.
```

---

## Tier 2 — Simple investigation

NPC output:

```text
20–35 words
```

Grammar:

```text
pretérito indefinido
object pronouns
porque
cuando
antes
después
```

Example:

```text
Lo vi ayer. Llegó solo, habló con el sacerdote y después se fue hacia el puente.
```

---

## Tier 3 — Narrative ambiguity

NPC output:

```text
35–55 words
```

Grammar:

```text
imperfecto
indefinido vs imperfecto
por / para
relative clauses
```

---

## Tier 4 — uncertainty and intention

Use:

```text
subjunctive
reported speech
conditional
probability
```

Example:

```text
No digo que el prior lo haya matado.
Digo que alguien quería que pareciera culpable.
```

---

## Tier 5 — pragmatic investigation

NPC output:

```text
60–90 words
```

Use:

```text
irony
euphemism
institutional language
indirect threat
unstated assumptions
conflicting interpretations
```

Example:

```text
El obispo no ordenó que lo arrestaran.
Simplemente declaró que nadie debía ofrecerle refugio.
Supongo que entiende la diferencia.
```

---

# 26. Learner model

Store mastery from `0.0–1.0`.

Grammar:

```json
{
  "ser_estar": 0.72,
  "hay": 0.85,
  "gender_articles": 0.70,
  "object_pronouns": 0.45,
  "gustar": 0.63,
  "present": 0.81,
  "perfect": 0.48,
  "preterite": 0.42,
  "imperfect": 0.31,
  "preterite_vs_imperfect": 0.25,
  "por_para": 0.38,
  "ir_a_future": 0.65,
  "imperative": 0.40,
  "se": 0.37,
  "reflexive": 0.55,
  "relative_clauses": 0.33,
  "subjunctive_basic": 0.11,
  "conditional": 0.22,
  "reported_speech": 0.18
}
```

---

# 27. Irregular verb mastery

Track separately:

```json
{
  "ser": 0.90,
  "ir": 0.76,
  "estar": 0.77,
  "tener": 0.71,
  "venir": 0.44,
  "decir": 0.48,
  "hacer": 0.65,
  "poder": 0.52,
  "poner": 0.39,
  "querer": 0.61,
  "saber": 0.57,
  "dar": 0.62,
  "ver": 0.48,
  "traer": 0.25,
  "conducir": 0.20,
  "andar": 0.32,
  "caber": 0.10,
  "haber": 0.42,
  "oir": 0.26,
  "caer": 0.31,
  "pedir": 0.44,
  "dormir": 0.49,
  "sentir": 0.46,
  "morir": 0.41,
  "seguir": 0.45
}
```

Scheduler target per learning event:

```text
60% weak/review
25% current level
15% stretch
```

---

# 28. Error memory

Each important error stores:

```json
{
  "tag": "preterite_ver",
  "count": 3,
  "last_seen_day": 4,
  "examples": [
    "yo veo ayer"
  ],
  "mastery_after": 0.42
}
```

Do not store every typo.

Store only recurring or pedagogically important errors.

---

# 29. Feedback policy

Never interrupt a dramatic conversation with “WRONG”.

If player writes:

```text
Yo fui aquí ayer y veo el hombre.
```

NPC can answer:

```text
Sí, vino ayer. ¿Dice que vio al hombre cerca de aquí?
```

Side panel:

```text
Meaning understood ✓

Better:
"Vi al hombre."

ver → vi
pretérito indefinido
```

Maximum explicit corrections:

```text
2 per turn
```

---

# 30. Required survival dialogues

These must appear throughout the campaign.

## Food

```text
Buenas tardes. ¿Tiene pan?
Sí. Dos monedas.
Deme dos, por favor.
```

## Water

```text
¿Hay agua potable?
Sí, detrás del establo.
```

## Medicine

```text
Necesito vendas.
¿Cuántas?
Tres. ¿Cuánto cuestan?
```

## Inn

```text
Necesito una habitación para esta noche.
Cinco monedas.
¿Incluye comida?
```

## Directions

```text
¿Cómo llego al monasterio?
Siga este camino y gire a la izquierda después del puente.
```

## Road safety

```text
¿Es seguro el camino del norte?
Seguro, no. Abierto, sí.
```

## Stable

```text
Necesito comida para el caballo.
¿Cuánto quiere?
Para dos días.
```

## Complaint

```text
Pedí aceite, no vino.
Eso fue lo que me pidió.
No. Le pedí aceite para la lámpara.
```

## Permission

```text
Necesito entrar.
No puede pasar.
Tengo una orden del tribunal.
Déjeme verla.
```

---

# 31. Language event cadence

Outside combat:

```text
every 5–10 minutes
```

there should be at least one of:

```text
free-text reply
question formulation
cloze
micro-recall
short summary
classification
transactional dialogue
timeline reconstruction
```

Do not run grammar drills during battle animations.

---

# 32. Quest format

Example:

```json
{
  "id": "dead_monk",

  "stages": [
    {
      "id": "discover_body",
      "requires": []
    },
    {
      "id": "question_innkeeper",
      "requires": ["discover_body"]
    },
    {
      "id": "inspect_gate",
      "requires": ["question_innkeeper"]
    }
  ]
}
```

All quest transitions must be deterministic.

---

# 33. Save system

Use one JSON save.

```text
user://savegame.json
```

Save:

```text
heroes
positions
world flags
quest stages
evidence graph
NPC relationships
NPC summaries
learner model
grammar mastery
verb mastery
inventory
day/time
```

Do not save:

```text
API key
full raw Claude histories
large prompt payloads
```

---

# 34. Offline mode

Game must remain playable if Claude API fails.

Every important NPC must have authored fallback branches.

If API is unavailable:

```text
show authored dialogue
disable detailed language analysis
continue quest normally
```

Never make an API call a hard quest gate.

---

# 35. Performance target

Target:

```text
Windows 10/11
1280×720
30 FPS minimum
60 FPS desirable
```

Avoid:

```text
3D
dynamic lighting
heavy shaders
large particle systems
physics-heavy scenes
local AI models
animated crowds
procedural world generation
```

Prefer:

```text
static sprites
tilemaps
simple UI
short audio loops
small portraits
```

---

# 36. Vertical slice

Do not build the full game first.

First playable:

```text
1 hero
20×20 map
1 inn
1 monastery
1 shop
1 guard checkpoint
1 battle
4 NPCs
1 murder
6 clues
1 false interpretation
Claude conversation
Spanish evaluation
save/load
```

Target playtime:

```text
30–45 minutes
```

Only after this works, scale content.

---

# 37. Epic plan

---

## EPIC 0 — Repository and agent discipline

### Goal

Make the project safe for autonomous Copilot work.

### Tasks

#### 0.1 Clone Open RPG

- clone upstream;
- verify it opens in Godot 4.6.2;
- run demo;
- create new git branch.

**Acceptance**
- project launches;
- no import errors.

#### 0.2 Create docs

Create all files under `/docs`.

**Acceptance**
- Copilot can find master spec;
- STATE.md exists.

#### 0.3 Remove irrelevant demo content

Delete only after identifying reusable systems.

**Acceptance**
- project still launches.

#### 0.4 Add project configuration

Create:

```text
/game/config/game.json
```

with model ID, language defaults and dev flags.

---

## EPIC 1 — Minimal world map

### Tasks

#### 1.1 Create map scene

Use TileMap/TileMapLayer.

#### 1.2 Add test terrain

20×20.

#### 1.3 Add camera pan/zoom

Mouse-driven.

#### 1.4 Add hero token

Click-to-select.

#### 1.5 Add AStarGrid2D

Path preview.

#### 1.6 Apply terrain costs

#### 1.7 Add end-turn button

**Acceptance**
- hero moves using movement points;
- forest costs more than road;
- impassable cells are respected.

---

## EPIC 2 — Fog and POIs

### Tasks

#### 2.1 Add fog states

#### 2.2 Reveal around hero

#### 2.3 Add location markers

#### 2.4 Add generic POI window

#### 2.5 Create inn and monastery examples

**Acceptance**
- unknown map stays hidden;
- discovered terrain remains explored;
- clicking a reachable POI opens modal UI.

---

## EPIC 3 — Core hero state

### Tasks

#### 3.1 Create HeroState resource/data

#### 3.2 Connect map token to HeroState

#### 3.3 Create inventory list

#### 3.4 Create resources

gold/food/medicine/horse_feed/lamp_oil.

#### 3.5 Add three-hero switching scaffold

Only one hero needs real content initially.

---

## EPIC 4 — Static dialogue first

### Tasks

#### 4.1 Reuse/create dialogue panel

#### 4.2 Add free-text input

#### 4.3 Add authored NPC reply mode

#### 4.4 Add dialogue log

#### 4.5 Add compact language-feedback panel

**Acceptance**
- player can type Spanish;
- NPC reply appears;
- dialogue can be closed/reopened.

---

## EPIC 5 — Claude client

### Tasks

#### 5.1 Read API key from environment

#### 5.2 Implement HTTP request

#### 5.3 Add timeout

Suggested:

```text
20 seconds
```

#### 5.4 Add one retry

#### 5.5 Parse JSON

#### 5.6 Validate schema

#### 5.7 Add fallback authored response

**Acceptance**
- malformed response cannot crash game;
- no API key does not block gameplay.

---

## EPIC 6 — NPC grounding

### Tasks

#### 6.1 Create NPC JSON schema

#### 6.2 Add knowledge list

#### 6.3 Add beliefs

#### 6.4 Add secrets

#### 6.5 Add lie policy

#### 6.6 Build prompt context

#### 6.7 Add canonical verifier

**Acceptance**
- NPC cannot reveal unknown clue;
- unknown clue ID from Claude is rejected.

---

## EPIC 7 — Spanish evaluation

### Tasks

#### 7.1 Parse meaning_understood

#### 7.2 Parse errors

#### 7.3 Display max two corrections

#### 7.4 Track grammar tags

#### 7.5 Track irregular verbs

#### 7.6 Update learner mastery

#### 7.7 Add recast behavior

---

## EPIC 8 — Grammar scheduler

### Tasks

#### 8.1 Create grammar profile

#### 8.2 Create verb profile

#### 8.3 Track recency

#### 8.4 Select focus for each dialogue

#### 8.5 Apply 60/25/15 scheduling

#### 8.6 Add anti-repetition rule

Do not force the same grammar target in more than 3 consecutive interactions.

---

## EPIC 9 — Conversation difficulty

### Tasks

#### 9.1 Add five difficulty dimensions

#### 9.2 Track success/failure

#### 9.3 Adjust one dimension at a time

#### 9.4 Map dimensions to prompt settings

#### 9.5 Add tier labels for debugging

---

## EPIC 10 — Evidence graph

### Tasks

#### 10.1 Create evidence data model

#### 10.2 Create notebook UI

#### 10.3 Show observation/claim/interpretation separately

#### 10.4 Allow player classification

#### 10.5 Add hypothesis links

#### 10.6 Add deterministic evidence gates

---

## EPIC 11 — One complete investigation

### Goal

Prove the whole game loop.

### Required content

```text
one dead monk
four NPCs
six canonical clues
one misleading but honest testimony
one deliberate lie
one irrelevant secret
one institutional document
one wrong hypothesis
one correct causal chain
```

### Acceptance

Player can:

```text
discover
talk
misinterpret
correct interpretation
fight once
buy supplies
save/load
reach a conclusion
```

---

## EPIC 12 — Battle integration

### Tasks

#### 12.1 Reuse existing turn-based battle scene

#### 12.2 Convert actors to stacks

#### 12.3 Add count-based damage

#### 12.4 Add defend

#### 12.5 Add one ability per stack type

#### 12.6 Add retreat

#### 12.7 Add simple enemy AI

#### 12.8 Hex battlefield: 11×7 hexes, starting columns, obstacles, terrain ground

#### 12.9 Movement: speed, reachable hexes, flying, move and attack-from-a-side commands

#### 12.10 Ranged rules: shooting, blocked shooters, retaliation only in melee

#### 12.11 Enemy AI with movement and battle screen with walking and strike animation

---

## EPIC 13 — Transactional Spanish

Implement reusable dialogue archetypes:

```text
merchant
innkeeper
healer
stable master
guard
toll collector
food seller
smuggler
```

Each archetype needs:

```text
easy version
medium version
hard version
```

---

## EPIC 14 — Save/load

### Tasks

#### 14.1 Serialize GameState

#### 14.2 Version save format

#### 14.3 Load from menu

#### 14.4 Autosave after major location events

#### 14.5 Corrupt-save handling

---

## EPIC 15 — Three heroes

### Tasks

#### 15.1 Inquisitor

#### 15.2 Smuggler

#### 15.3 Survivor

#### 15.4 Switching

#### 15.5 Independent location

#### 15.6 Independent inventory/army

#### 15.7 Shared evidence notebook

---

## EPIC 16 — Full map

Only begin after vertical slice passes.

### Tasks

#### 16.1 Create 160×120 map

#### 16.2 Define regions

#### 16.3 Add roads

#### 16.4 Add major POIs

#### 16.5 Add gates

#### 16.6 Add optional routes

#### 16.7 Add fast-travel only if playtest proves necessary

---

## EPIC 17 — Scenario acts

Implement content in acts.

```text
ACT I   The Body
ACT II  The Official Truth
ACT III Contradictory Signs
ACT IV  The Survivor
ACT V   The Interpreting Machine
ACT VI  Institutional Reality
ACT VII Choice
```

Do not encode story logic inside Claude prompts.

All facts live in JSON scenario content.

---

## EPIC 18 — Institutional speech acts

### Tasks

#### 18.1 Add declaration records

#### 18.2 Validate authority

#### 18.3 Validate procedure

#### 18.4 Apply world consequences

#### 18.5 Connect to evidence notebook

---

## EPIC 19 — NPC long-term memory

### Tasks

#### 19.1 Store discussion topics

#### 19.2 Store revealed clues

#### 19.3 Store lies told

#### 19.4 Store relationship

#### 19.5 Generate bounded conversation summary

#### 19.6 Validate summary against known facts

---

## EPIC 20 — Polish

Only after full scenario is playable.

Possible:

```text
portraits
better tiles
sound
music
small animations
better map markers
better evidence UI
```

No feature work.

---

# 38. Test strategy

## 38.1 Unit tests

Required examples:

```text
road costs 1 MP
forest costs 2 MP
mountain is impassable
unknown clue ID is rejected
NPC cannot reveal clue outside knowledge
invalid speech act cannot change institutional state
grammar mastery remains in 0..1
```

---

## 38.2 Integration tests

Examples:

```text
move → enter inn → talk → buy food → save → reload
```

and:

```text
talk → Claude suggests clue → verifier accepts → evidence appears
```

---

# 39. Golden conversation tests

Create at least 30.

Example:

```text
PLAYER:
Yo veo hombre ayer.

EXPECTED:
meaning_understood = true
preterite error detected
NPC remains in character
NPC uses a natural recast with vi/vio
story continues
```

Example:

```text
PLAYER:
¿Quién mató al monje?

NPC does not know.

EXPECTED:
NPC must not invent a murderer.
```

Example:

```text
PLAYER:
El obispo dijo que nadie puede ayudarlo. ¿Eso fue una orden?

EXPECTED:
NPC may discuss whether it was an order/declaration,
but cannot decide institutional validity unless canonical data allows it.
```

---

# 40. Development gates

Copilot may not proceed to a later gate until the current gate is green.

## Gate A

```text
map movement works
```

## Gate B

```text
POI + authored dialogue works
```

## Gate C

```text
Claude dialogue works
```

## Gate D

```text
language evaluation works
```

## Gate E

```text
evidence verifier works
```

## Gate F

```text
one full investigation works
```

## Gate G

```text
save/load works
```

## Gate H

```text
three heroes work
```

## Gate I

```text
full scenario content expansion
```

---

# 41. First implementation sequence

Copilot should execute this exact sequence.

Dependency clarification (2026-10-05): step 13 first completes the investigative loop. Its Epic 11 acceptance also requires the battle and purchase implemented immediately in steps 14 and 15. Keep Gate F pending through these constituent steps, then verify the combined loop before advancing to later gates. This resolves the dependency without claiming unimplemented checks passed.

```text
01 repository boots
02 hero moves
03 pathfinding works
04 POI opens
05 static dialogue works
06 Claude call works
07 JSON response validates
08 Spanish feedback appears
09 NPC grounding works
10 save/load works
11 evidence node appears
12 one clue unlock works
13 one complete investigation works
14 one battle works
15 transactional merchant dialogue works
16 grammar scheduler works
17 second hero added
18 third hero added
19 full map created
20 remaining acts added
```

---

# 42. Definition of Done for MVP

MVP is complete only if all are true:

```text
[ ] Game starts on weak Windows machine.
[ ] Player can move hero on map.
[ ] Terrain costs work.
[ ] Fog works.
[ ] At least four POIs work.
[ ] One shop works.
[ ] One inn works.
[ ] One battle works.
[ ] Claude conversation works.
[ ] Game survives Claude outage.
[ ] Spanish errors are shown without blocking dialogue.
[ ] Learner profile updates.
[ ] Irregular verb mastery updates.
[ ] Evidence graph works.
[ ] Claude cannot invent canonical clue unlocks.
[ ] One complete murder investigation can be solved.
[ ] Save/load preserves investigation and learner state.
```

---

# 43. Definition of Done for full game

```text
[ ] 3 playable heroes
[ ] 160×120 world map
[ ] 4–5h critical path
[ ] 8–10h total content
[ ] 30+ meaningful NPCs
[ ] all core grammar categories recur
[ ] all target irregular verbs recur
[ ] transactional Spanish is mandatory in multiple regions
[ ] conversation difficulty increases adaptively
[ ] NPCs remember relevant prior interaction
[ ] evidence graph supports competing interpretations
[ ] institutional speech acts alter world state
[ ] all endings are deterministic
[ ] game remains playable without Claude
[ ] no copyrighted HoMM assets or data are required
```

---

# 44. Non-goals

Do not implement:

```text
multiplayer
online accounts
voice input
speech synthesis
procedural campaign generation
dynamic world simulation
realistic economy
complex tactical AI
crafting
skill trees with dozens of nodes
3D
cinematics
fully animated interiors
mod SDK
Steam integration
cloud saves
mobile version
```

---

# 45. Risk register

## Risk 1 — Copilot over-engineers

Mitigation:

```text
strict COPILOT.md
small tasks
architecture freeze
task gates
```

## Risk 2 — Claude invents facts

Mitigation:

```text
bounded NPC knowledge
structured JSON
deterministic verifier
golden tests
```

## Risk 3 — language learning becomes annoying

Mitigation:

```text
implicit recasts
max two corrections
micro-events
grammar scheduling
difficulty dimensions
```

## Risk 4 — map feels empty

Mitigation:

```text
POI density
road encounters
transactional dialogue
evidence events
optional shortcuts
```

## Risk 5 — scope explodes

Mitigation:

```text
modal interiors
7-stack battles on a fixed 11×7 hex field
fixed map
fixed scenario
no multiplayer
no local AI
```

---

# 46. Final implementation rule

When there is a choice between:

```text
more realistic
more generic
more extensible
```

and:

```text
simpler
more deterministic
easier for Copilot
easier to test
```

choose the second option.

This game exists for one player.

Architecture must optimize for completing the game, not for building a reusable engine.

---

# 47. External references

Primary implementation references:

- Godot Engine — MIT-licensed free/open-source engine.
- GDQuest `godot-open-rpg` — MIT-licensed Godot 4 RPG demo with turn-based combat, inventory, maps, dialogue, grid movement and UI.
- Anthropic Claude Platform — use an active Claude model via Messages API.
- Keep `claude-sonnet-5-5` configurable rather than permanently hard-coded.
- Anthropic prompting guidance supports explicit structured prompts and XML-delimited context.
- Do not set legacy sampling parameters such as custom temperature/top_p/top_k for modern Claude models unless current documentation explicitly allows them.
- Always re-check Anthropic model lifecycle before a long break in development.

---

# 48. Immediate next task for Copilot

Use this exact task:

```text
TASK: Bootstrap vertical-slice repository.

Read docs/MASTER_BUILD_SPEC.md and docs/COPILOT.md.

1. Clone gdquest-demos/godot-open-rpg as the project base.
2. Confirm it opens with Godot 4.6.2.
3. Preserve the reusable turn-based combat, dialogue, inventory and UI systems.
4. Remove only demo-specific story content that is clearly separable.
5. Create the repository folder structure defined in MASTER_BUILD_SPEC.md.
6. Create docs/STATE.md documenting:
   - current upstream commit,
   - systems retained,
   - systems removed,
   - known import/runtime issues.
7. Do not implement new gameplay yet.
8. Run the project.
9. Commit as:
   "chore: bootstrap project from GDQuest Open RPG"

Acceptance criteria:
- Project opens in Godot 4.6.2.
- Main scene runs without fatal errors.
- Repository structure matches spec.
- STATE.md is accurate.
- No speculative refactor has been introduced.
```

After this commit, begin **EPIC 1 — Minimal World Map**.

# 49. User-requested side investigation expansion (2026-10-05)

Author 108 additional optional quests and 108 associated battle encounters in 12
parallel original investigations. Each case combines collectible evidence, competing
interpretations, a solvable puzzle and a local consequence. Scholarly mysteries and
semiotics inform the design; do not copy existing novels' characters or plots.

The authored catalog is game/content/scenario/side_investigations.json; its index and
limitations are in docs/SIDE_INVESTIGATIONS.md. SX/AX/BX/SB identifiers are reserved
for this expansion and do not replace the bible's original SQ quests.

All 108 quests require active Spanish production and consolidation. Language follows
the ordered blocks in section 1.3; quest completion never independently unlocks a
tense. Earlier learning must be consolidated before later tasks become available.
All purchases still require language practice as specified in section 1.2.

Status update (2026-10-07, user decision): the catalog is integrated at runtime. All
108 cases are reachable from the province map with peaceful and battle custody,
written Spanish stages, later-day recall and save persistence; the catalog status is
runtime_integrated_unbalanced. This was built after steps 01-20 and before the
remaining full-game criteria of section 43; the user accepted that ordering after the
fact. Not implemented: the twelve cross-branch links, world consequences of the 24
disclosure outcomes, and per-quest language prompts (nine shared templates are used).
Balance is unplaytested. The main plot and section 43 remain the development priority.
Playing every optional case is additional content, not part of the original
campaign-duration estimate. Do not claim the encounters are balanced.

# 50. Equipment, soul assemblies and simultaneous ghost opponents (2026-10-05)

User requests 20-30 equipment types spanning ordinary items to highest-rank combined
artifacts with souls, and distinct ghost knights embodying the verbal/semiotic enemy.
The authored catalogs define 30 types, five ordinary tiers and soul as the sixth/highest
tier: 150 ordinary items, 24 unique components and six assemblies. See
docs/EQUIPMENT_AND_GHOST_KNIGHTS.md for the full rules and content index.

Adopt the equipment-combination pattern of Heroes III: individual bonuses persist,
all component slots stay reserved, assembly can be reversed. Do not copy its assets,
item names or spells. Use a plain inventory list and fourteen equipment slots, no grid.
Assembly additionally requires the same hero to persuade the fragmented soul in Spanish:
evidence from memories, independent argument, objection and delayed recall, respecting
the ordered curriculum. No model-only success flag or phrase click may grant consent.
All purchases still require active Spanish. Components/evidence cannot be consumed,
duplicated or lost during assembly. Another hero needs their own consent for full power.

Eight distinct knight profiles choose different targets and bounded interventions.
Province strategic turns use simultaneous planning from a shared snapshot, frozen AI
orders before player commit, deterministic collision resolution and an atomic save.
Typing and language feedback never advance hostile turns. Keep at most three active
knights, two interventions per day and one active effect per branch, lasting at most
two turns. Every effect has traces, counterplay and recovery; owned evidence/equipment,
soul consent and canonical main mystery cannot be rewritten by an opponent or model.

Status update (2026-10-07, user decision): equipment, soul assemblies and ghost knights
are integrated at runtime (save v12). The province day loop is the simultaneous one:
routes are queued against frozen knight orders and resolved together; the 20x20
development map keeps the immediate-move loop. While orders are frozen, purchases,
construction, case steps, campaign tasks, equipment changes and hero handovers are
refused until the day is resolved. Not implemented: sources for the 90
optional-treasure items, the per-set soul special actions (every set currently reduces
a counter from two evidence sources to one), and any balance playtest. Catalog
statuses: equipment runtime_integrated_partial_acquisition, ghost knights
runtime_integrated_unbalanced.

## Ordered curriculum implementation thresholds (2026-10-06)

The initial authored course contains 31 topics over the seven ordered blocks. Each
topic requires introduction, guided production, two changed-context productions and
recall on a later game day. All topics of a block precede advancement. These are initial
engineering thresholds, not a calibrated claim of fluency or real-time spaced retention.
Guided work does not award free-language mastery. Save validation rechecks the proofs.
future_simple is an additional grammar metric distinct from ir_a_future.

After consolidation, the focus cycle is 12 weak/review, 5 current and 3 stretch slots
per 20 dialogue requests. During consolidation, stretch becomes current practice.
Stretch increases vocabulary/sentence demands within taught grammar; new tenses follow
lesson prerequisites. Three understood exchanges adjust one dimension by 0.05; two
comprehension failures reduce one pressure dimension by 0.04, capped at 0.10 per
conversation. Uncertain and duplicate productions cannot drive these adjustments.