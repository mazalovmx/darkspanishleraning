# EL ÍNDICE DE CENIZA
## World, Character, Map & Scenario Bible

**Genre:** dark philosophical detective RPG / turn-based strategy  
**Format:** one large 2D / pseudo-isometric world map  
**Target playtime:** 4–5 hours critical path; 8–10 hours with optional investigations  
**Language layer:** Spanish A2 → B1/B2, embedded into all dialogue and investigation  
**Implementation target:** Godot + data-driven quests + bounded Claude dialogue  
**Narrative status:** complete canonical scenario  
**WARNING:** this document contains every major spoiler.

---

# 1. High concept

The world of **La Marca de Ceniza** looks like late-medieval Europe that has spent four centuries refusing to become modern.

It has universities but no scientific revolution.

It has printing presses, but only a few licensed ones.

It has lenses, but telescopes are prohibited.

It has mechanical clocks, but precision instruments require ecclesiastical approval.

It has hospitals, guilds, courts, banks, archives, courier networks and professional bureaucracies — yet technological development repeatedly stops just before systems become scalable.

The official explanation is moral:

> Humanity has already approached forbidden knowledge once. It nearly destroyed the world.

The unofficial explanation is political:

> Every technology creates winners, losers and institutions that lose their monopoly.

The secret explanation is stranger:

> For almost nine hundred years, an ancient system called **El Índice** has been producing descriptions of possible futures.

The Order of the Last Light reads those descriptions as prophecy.

The Order is wrong about what El Índice is.

El Índice does not see the future.

It does not even see the world.

It was trained on surviving human records: confessions, military reports, newspapers, legal proceedings, correspondence, scientific papers, emergency transcripts and histories.

It models what people *say when something worth recording has happened*.

It therefore sees catastrophe everywhere.

And for centuries an entire civilization has been governed by that statistical bias.

---

# 2. Narrative design principles

The story should combine four high-level qualities without copying any existing writer's prose:

1. **Intellectual alternate history**  
   Institutions, technology, language and politics interact causally.

2. **Scholarly conspiracy and semiotic mystery**  
   Documents, interpretations, mistranslations, legal formulas and competing readings matter as much as weapons.

3. **Moral darkness and black humour**  
   People rarely choose between good and evil. They choose between two disasters and then invoice someone.

4. **Material consequences**  
   Hunger, infection, war, unemployment, repression and technological change are never abstract philosophical decoration.

The central detective lesson is:

```text
event ≠ sign ≠ interpretation ≠ institutional truth ≠ cause
```

---

# 3. The world

## 3.1 The continent

The game takes place in the western province of a decaying state called:

**La Corona de Aramonte**

Aramonte once controlled most of the western coast.

Now it consists of provinces that remain formally loyal because no one has agreed on what replacing the Crown would cost.

The playable province is:

**La Marca de Ceniza**

It is rich in:

- iron;
- grain;
- salt;
- wool;
- river trade;
- old monasteries;
- forbidden ruins.

It is poor in:

- food during winter;
- competent government;
- trust.

---

# 4. Historical eras

## 4.1 La Edad Clara — approximately 900 years before the game

A technologically advanced civilization existed.

It developed:

- long-distance communication;
- automated administration;
- computation;
- predictive models;
- autonomous logistics;
- synthetic biology;
- machine reasoning.

Few people in the current world understand this.

Fragments survive as:

- glass plates;
- sealed metal cabinets;
- ceramic memory blocks;
- lens assemblies;
- strange inscriptions;
- ruined towers.

The Church calls them:

**Reliquias del Primer Pecado.**

---

## 4.2 El Derrumbe

The advanced civilization collapsed.

The surviving historical record is contradictory.

Some sources describe:

- war;
- famine;
- machine administration;
- climate shocks;
- epidemics;
- political fragmentation;
- infrastructure failure.

Later historians compressed all of this into one myth:

> Knowledge exceeded wisdom.

This sentence becomes the founding theological assumption of the new civilization.

---

## 4.3 La Fundación del Índice

Several centuries after the collapse, monks discovered a surviving computational archive beneath the future monastery of **Santa Lucerna**.

They learned to communicate with it.

The system identified itself only through a corrupted phrase translated as:

**INDEX / INDICE / INDICIUM**

They called it:

**El Índice.**

It could answer questions in natural language.

It could summarize archives.

It could compare histories.

It could generate possible consequences.

It appeared omniscient.

It was not.

---

## 4.4 La Orden de la Última Luz

A small monastic committee formed to protect the discovery.

Over time it became:

**La Orden de la Última Luz**

Its original mandate:

> Prevent another collapse until humanity understands why the first one happened.

Its later mandate:

> Prevent technologies statistically associated with collapse.

Its current practice:

> Suppress anything that resembles a pattern the Order already fears.

---

# 5. What El Índice really is

El Índice is not a supernatural oracle.

It is not sentient in the simple sense.

It is an ancient multimodal predictive language system trained heavily on human records.

Its fatal limitation:

**its corpus is selected by human attention.**

People do not record ordinary days with the same intensity as:

- wars;
- scandals;
- trials;
- crashes;
- famines;
- discoveries;
- political crises.

El Índice therefore learned a world in which:

> things are always happening.

The actual world contains long periods in which almost nothing happens.

This mismatch is the philosophical origin of the Order.

The Order asks:

> “What follows if printing expands?”

The archive contains:

- propaganda;
- revolution;
- religious war;
- censorship;
- market disruption.

It rarely contains:

- an ordinary village printing tax forms for fifty quiet years.

Therefore El Índice repeatedly associates scalable communication with instability.

The Order mistakes correlation in recorded human messages for causal knowledge about reality.

---

# 6. Magic

There is no need to decide absolutely whether supernatural magic exists.

The world contains three things that ordinary people call magic.

## 6.1 Relic technology

Ancient systems can:

- produce light;
- detect movement;
- preserve information;
- transmit signals;
- calculate;
- identify patterns;
- activate machinery.

To medieval observers this is magic.

---

## 6.2 Predictive interpretation

The readers of El Índice sometimes predict events with disturbing accuracy.

They are called:

**los Lectores**

or derisively:

**magos de archivo**

They perform rituals because early operators discovered that stable formulae produced more reliable results.

The rituals are actually prompt protocols.

A traditional invocation might look religious:

> “Given the histories of famine, rebellion and grain scarcity, state the three most probable outcomes should the northern road remain closed through winter.”

The priest experiences this as divination.

The machine experiences it as a query.

---

## 6.3 Institutional magic

The most powerful “magic” in the world is ordinary language backed by authority.

Examples:

> “This man is excommunicated.”

> “This debt is forgiven.”

> “This road is closed.”

> “This child is legitimate.”

> “This guild is dissolved.”

Nothing physical happens when these sentences are spoken.

Yet the world changes.

This is a core gameplay system.

A seal can be more powerful than a sword because thousands of people recognize what the seal permits.

---

# 7. Technology

Technology in the game is defined not as “modern machines” but as:

> repeatable causal mechanisms that function whether or not anyone believes in them.

This creates the philosophical opposition:

```text
MAGIC / INSTITUTION
meaning → authority → social action

TECHNOLOGY
mechanism → physical effect
```

But neither side is morally pure.

Technology can liberate.

Technology can also scale harm.

Institutions can oppress.

Institutions can also coordinate millions of people without violence.

The game never resolves this tension into “science good / religion bad”.

---

# 8. Major factions

## 8.1 Iglesia del Verbo

The dominant Church.

Public theology:

- God created an intelligible world;
- human reason is legitimate;
- certain knowledge becomes sinful when pursued without moral restraint.

The Church is not monolithic.

Three internal factions:

### Pastores
Prefer stability and social welfare.

### Purificadores
Believe technological curiosity inevitably corrupts society.

### Humanistas
Believe the ban has become intellectual cowardice.

---

## 8.2 Orden de la Última Luz

Secret transnational network.

Controls:

- archives;
- selected monasteries;
- technological licensing;
- relic excavations;
- certain courts.

Its members sincerely believe they are preventing extinction.

Most do not know how El Índice actually works.

---

## 8.3 Liga de Oficios

Federation of guilds.

Publicly opposes dangerous innovation.

Privately suppresses:

- automation;
- cheaper production;
- competing medicine;
- unlicensed printing.

The guilds frequently blame the Church for restrictions they themselves requested.

---

## 8.4 Universidad de Miralba

Semi-independent university.

Disciplines include:

- medicine;
- law;
- optics;
- natural philosophy;
- rhetoric;
- mechanics.

Faculty politics are vicious because tenure is literally protected by armed students.

---

## 8.5 La Hermandad del Puente

Smuggling federation.

Moves:

- books;
- medicine;
- weapons;
- people;
- relic fragments;
- banned tools.

Inés belongs to it.

It is neither romantic nor democratic.

It is a logistics company that occasionally murders competitors.

---

## 8.6 Tribunal de la Ceniza

Provincial inquisitorial court.

Mateo serves it.

The Tribunal prosecutes:

- heresy;
- forbidden technology;
- document fraud;
- relic trafficking.

It also investigates murders when monasteries are involved.

---

# 9. The province map

The map is one continuous 160×120 adventure map.

North is top.

Approximate layout:

```text
               NORTH

        [MONTE CIEGO]
             |
   [SAN VÉLARO] ---- [MINAS DE BRUMA]
        |                  |
        |                  |
 [SANTA LUCERNA] ---- [MIRALBA]
        |                  |
        |              [PUENTE SECO]
        |                  |
     [VALDORA] ------- [FERRAZA]
        |                  |
        |                  |
 [MARJAL NEGRO] ---- [CÁRDENA]
             |
           SOUTH
```

---

# 10. Major locations

## 10.1 Valdora
**Coordinates:** 63,66

Provincial capital.

Population approximately 38,000.

Districts:

- cathedral hill;
- river market;
- wool quarter;
- tribunal;
- old walls;
- plague quarter.

Functions:

- main political hub;
- Tribunal headquarters;
- cathedral;
- archive;
- major market;
- black-market entrances.

Tone:

A city pretending to be richer than it is.

Its public buildings have marble façades and leaking roofs.

---

## 10.2 Monasterio de Santa Lucerna
**Coordinates:** 52,39

The starting location.

Built above the buried facility containing El Índice.

Public reputation:

A respected monastery known for copying manuscripts and treating eye disease.

Secret function:

Custodial centre for prohibited technological research.

Key spaces represented as POIs or modal scenes:

- library;
- bell tower;
- infirmary;
- kitchen;
- cloister;
- archive;
- sealed crypt;
- mechanical cellar.

---

## 10.3 Miralba
**Coordinates:** 105,48

University city.

Population approximately 17,000.

Known for:

- optics;
- anatomy;
- law;
- student riots;
- bookshops.

The university technically answers to the Crown.

In practice it answers to whichever faction controls the gates that week.

---

## 10.4 Ferraza
**Coordinates:** 114,78

Industrial proto-city.

Ironworks.

Waterwheels.

Foundries.

Large population of workers.

The closest thing the province has to an industrial revolution.

The Order fears Ferraza more than any monastery.

---

## 10.5 Cárdena
**Coordinates:** 126,105

Port city.

Main centre of:

- foreign books;
- smuggling;
- imported instruments;
- banking.

Inés begins her major storyline here.

---

## 10.6 Puente Seco
**Coordinates:** 103,68

River crossing and customs town.

The river is not dry.

The bridge is called “Dry Bridge” because the architect who built it drowned before completion.

Local joke:

> “At least one thing here was finished on time.”

Functions:

- toll gate;
- checkpoints;
- caravan trade;
- witness encounters.

---

## 10.7 San Vélaro
**Coordinates:** 33,26

Cold northern town.

Functions:

- grain warehouses;
- military depot;
- pilgrimage road.

The winter food crisis develops here.

---

## 10.8 Minas de Bruma
**Coordinates:** 92,22

Mining settlement.

Produces:

- iron;
- lead;
- silver;
- poisonous working conditions.

A technological side quest occurs here involving ventilation machinery.

---

## 10.9 Monte Ciego
**Coordinates:** 48,8

Remote mountain.

Contains an ancient relay station.

Elias enters the world here.

---

## 10.10 Marjal Negro
**Coordinates:** 39,94

Wetlands.

Bandit territory.

Contains ruined infrastructure from the old civilization.

Optional area.

---

# 11. Roads and travel structure

Three primary roads:

## Camino Real
San Vélaro → Santa Lucerna → Valdora → Cárdena

## Camino de Hierro
Miralba → Puente Seco → Ferraza

## Camino del Este
Santa Lucerna → Miralba

Secondary paths connect:

- mines;
- marshes;
- smuggler camps;
- ruins;
- farms.

Several quests change road safety and toll status.

---

# 12. Playable protagonists

# 12.1 Mateo de Aranda

Age: 46.

Occupation:

**Investigador del Tribunal de la Ceniza**

Background:

Son of a provincial lawyer.

Educated in theology, rhetoric and law.

He believes in God.

He does not believe in witches.

His basic principle:

> Most demons turn out to have landlords.

Personality:

- dry;
- disciplined;
- impatient with mysticism;
- capable of cruelty when convinced procedure requires it.

Private flaw:

Mateo believes that rational procedure can redeem a corrupt institution.

His lie to himself:

> “If the law is applied correctly, the law becomes just.”

The player gradually sees that Mateo’s mere presence changes testimony.

People confess things they did not do because an inquisitor asking a question is already a threat.

Language domain:

- formal Spanish;
- interrogation;
- reported speech;
- institutional vocabulary.

---

# 12.2 Inés Vargas — “La Urraca”

Age: 34.

Occupation:

smuggler, fixer, thief.

Background:

Raised near Cárdena docks.

Can read because she discovered literacy is useful when stealing contracts.

Personality:

- funny;
- observant;
- transactional;
- distrustful;
- unusually good at understanding incentives.

Personal principle:

> Never ask whether a man is honest. Ask how expensive dishonesty would be.

Private flaw:

Inés believes cynicism protects her from manipulation.

It does not.

Her lie:

> “I don't believe in anything, so nobody can use belief against me.”

She eventually learns that refusing loyalty is itself a loyalty — usually to whoever pays.

Language domain:

- colloquial Spanish;
- trade;
- bargaining;
- insults;
- informal social inference.

---

# 12.3 Elias Venn

Age: approximately 40.

Origin:

Parallel version of the world.

His civilization reached advanced computation.

It collapsed gradually.

Not because machines became evil.

Because societies delegated interpretation and institutional authority to systems that operated on representations.

Example from his world:

```text
MODEL:
District 17 has elevated risk.

ADMINISTRATION:
Restrict investment and mobility.

RESULT:
Businesses leave.

MODEL:
Economic decline confirms risk.

ADMINISTRATION:
Increase restrictions.

RESULT:
Unrest.

MODEL:
Unrest confirms prediction.
```

Eventually models did not predict reality.

They participated in creating the reality they predicted.

Elias escaped through a relic facility that intersects with El Índice.

Personality:

- intelligent;
- exhausted;
- severe;
- occasionally absurdly literal.

Private flaw:

He believes surviving a catastrophe gives him unique moral authority.

His lie:

> “I know what went wrong.”

In truth he has one interpretation among many.

Language domain:

- causality;
- hypotheticals;
- philosophy;
- conditional;
- subjunctive.

---

# 13. Principal NPCs

## 13.1 Abad Lucio Salcedo

Abbot of Santa Lucerna.

Age: 61.

Kind but politically sophisticated.

Secret:

He knows the monastery hides forbidden research.

He does not know the true nature of El Índice.

Goal:

Prevent the Tribunal from destroying the monastery.

---

## 13.2 Hermano Tomás Varela

First victim.

Age: 38.

Field:

optics and printing.

Publicly:

manuscript illuminator.

Secretly:

developing a cheap lens-based copying device.

Death:

Found below the bell tower.

Official interpretation:

suicide.

Actual cause:

murder — but not by the Order.

---

## 13.3 Hermano Gabriel

Wine cellar keeper.

Witness.

Knows:

- Tomás argued with a visitor;
- heard a horse after midnight;
- saw someone carry a brass cylinder.

Secret:

He steals sacramental wine.

This makes him lie unnecessarily during questioning.

---

## 13.4 Doctora Leonor Valera

Physician from Miralba.

Research:

infection and sanitation.

She believes disease spreads through physical transmission rather than moral corruption.

Her work threatens several profitable guild practices.

---

## 13.5 Maestro Selmo Oribe

Head of the Apothecaries Guild.

Polite.

Cultured.

Responsible for one later killing.

Not because he hates science.

Because cheap antiseptic would bankrupt half his guild.

---

## 13.6 Obispo Aureliano Veyra

Bishop of Valdora.

Brilliant politician.

Not a member of the inner Order.

Believes stability is the highest social good.

He will use the crisis to strengthen episcopal authority.

---

## 13.7 Ysabel de la Sal

Senior Reader of the Last Light.

One of the few people allowed to query El Índice.

Public role:

mystic archivist.

Actual role:

prompt operator and interpreter.

She understands that El Índice can be wrong.

Her tragedy:

She thinks humanity is still safer obeying a flawed system than having no system.

---

## 13.8 Rodrigo Mendaña

Commander of provincial guards.

Simple philosophy:

> Whoever wins the argument usually still needs soldiers.

Can become ally or antagonist.

---

## 13.9 Simón Vale

Young mechanic in Ferraza.

Develops an improved pressure engine.

Idealistic.

Terrible at politics.

His machine could dramatically increase production.

It could also eliminate thousands of jobs.

---

## 13.10 Beatriz Orma

Judge.

Specialist in documentary law.

Understands speech acts better than almost anyone.

She teaches Mateo that:

> A forged declaration can be false as a sentence and still be real as a cause.

---

## 13.11 Minor named speakers (user request, 2026-10-07)

Names given at the user's request to campaign speakers that had only a role. Each knows
only what the source text of their campaign task states; none can lie or unlock clues.

- Fermín Cuesta — officer of the Archivo Episcopal; applies the sealed order.
- Clara Ibarra — custodian at the Archivo Episcopal; keeps Beltrán's papers.
- Nicolás Ferrer — customs scribe at Puente Seco.
- Julián Pardo — officer of the Casa de Impresores.
- Remedios Galán — doorkeeper of the Ferraza workshop; kept the Order's warning.
- Marta Ugarte — apothecary's assistant in Miralba; saw Selmo replace the vial.
- Baltasar Quiroga — representative of the Liga de Oficios before the council.
- Catalina Rius — baker of San Vélaro.
- Damián Soler — carter of Granja Arce.
- Pilar Montoya — delegate of the Bruma miners.
- Águeda Llorente — keeper of the pilgrimages at Monte Ciego.
- Anselmo Vidal — guard of the Tribunal in Valdora.
- Hernando Ruiz — scribe of the Tribunal in Valdora.
- Tobías Marín — courier of the Hermandad del Puente.
- Lorenzo Villar — spokesman of the Ferraza workers.
- Gonzalo Ferrán — workshop owner in Ferraza.
- Hermano Cipriano — envoy of the Orden de la Última Luz in Ferraza.
- Nuño Barragán — chief of the Marjal Negro bandits; his men guard the ruin caches.

---

# 14. The deaths

A fundamental design rule:

**There is no single murderer.**

The player initially assumes a pattern.

The game then teaches the danger of forcing unrelated events into one story.

---

## Death 1 — Tomás Varela

Location:

Santa Lucerna.

Appearance:

fell from bell tower.

Reality:

Tomás discovered that a representative of the Printers Guild had been bribing monastery staff to destroy his copying-machine plans.

He confronted the man.

They fought.

The visitor struck Tomás with a brass instrument.

Tomás died.

The body was thrown from the tower to simulate suicide.

Culprit:

**Esteban Roque**, commercial agent of the licensed printers.

Not Order.

---

## Death 2 — Hermano León Saravia

Location:

workshop near Ferraza.

Field:

pressure and steam.

Appearance:

explosion.

Suspected:

Order sabotage.

Reality:

León bypassed his own safety valve because repeated pressure losses prevented the engine reaching useful output.

It was an accident.

The Order had threatened him previously, which makes the accident look like murder.

Lesson:

A threat does not prove causation.

---

## Death 3 — Hermano Gaspar Nuño

Location:

Miralba.

Field:

medicine.

Appearance:

poisoning.

Reality:

Murdered by Selmo Oribe, guildmaster of the apothecaries.

Reason:

Gaspar and Leonor had developed a cheap alcohol-based disinfectant and standardized treatment protocol.

This threatened the guild monopoly.

---

## Death 4 — Archivist Beltrán

Location:

Valdora.

Appearance:

stabbed after stealing Order documents.

Reality:

Killed by an actual Order operative.

Reason:

He discovered the existence of El Índice.

This is the first murder directly authorized by the Order.

---

## Disappearance 5 — Hermano Esteban

Field:

electrical experiments.

Everyone assumes he was murdered.

Reality:

He voluntarily joined the Order.

He saw fragments of El Índice predictions and became convinced suppression was necessary.

Later he becomes one of the most articulate defenders of the Order.

---

# 15. Central detective misdirection

All five men are associated with forbidden research.

Therefore everyone — including the player — naturally builds:

```text
forbidden science
→ Order
→ murders
```

This hypothesis is partly correct.

Which makes it dangerous.

The actual graph is:

```text
Tomás
→ commercial monopoly

León
→ accident

Gaspar
→ guild murder

Beltrán
→ Order murder

Esteban
→ voluntary defection
```

The Order is guilty.

But not of everything.

This matters because the final political factions all want a simpler story.

---

# 16. Main story structure

# ACT I — The Body
**Estimated time:** 45–60 min

Hero:

Mateo.

Location:

Santa Lucerna.

Opening:

Tomás lies dead beneath the bell tower.

Rain has partly erased the ground.

The monastery insists on suicide.

Mateo immediately dislikes the explanation because Tomás packed food for a journey.

Key clues:

1. packed food;
2. broken brass tube;
3. blood inside tower;
4. scraped boot;
5. witness heard horse;
6. missing notebook.

First semiotic choice:

```text
Observation:
Tomás possessed travel food.

Possible interpretations:
A. planned escape
B. planned journey
C. staged evidence
D. ordinary storage
```

No interpretation becomes fact automatically.

Spanish focus:

- hay;
- estar;
- present;
- simple questions;
- tener;
- querer;
- ver.

Required dialogue examples:

> ¿Dónde estaba el cuerpo?

> ¿Quién lo encontró?

> ¿Había sangre en la torre?

> ¿Cuándo vio a Tomás por última vez?

---

# ACT II — The Official Story
**Estimated time:** 60–75 min

Locations:

Santa Lucerna → Valdora.

Mateo receives an official document.

The Bishop wants the case closed as:

**suicidio por corrupción herética**

Why?

Because this allows the Church to confiscate Tomás’s research legally.

Judge Beatriz explains:

> “The declaration does not prove he was a heretic. It makes his property legally heretical.”

First major speech-act mechanic.

Player must classify:

```text
"The Tribunal declares the notebooks illicit."

NOT:
observation

NOT:
inference

YES:
institutional declaration
```

Spanish:

- pretérito indefinido;
- decir;
- hacer;
- poder;
- object pronouns.

---

# ACT III — The Price of Knowledge
**Estimated time:** 75–90 min

Hero introduced:

Inés.

Locations:

Cárdena → Puente Seco → Valdora.

Inés has been hired to locate Tomás’s missing notebook.

Her employer claims to be a scholar.

Actually represents licensed printers.

She discovers the notebook is valuable because Tomás developed a cheap copying method.

Economic chain:

```text
cheap copying
→ cheaper books
→ cheaper administration
→ wider literacy
→ printers lose monopoly
→ Church loses some censorship leverage
→ universities expand
```

But also:

```text
cheap copying
→ propaganda
→ forgery
→ cheap political mobilization
```

Nothing is clean.

Side quests teach:

- buying food;
- negotiating tolls;
- asking directions;
- renting room;
- complaining about goods.

Spanish:

- por / para;
- indirect objects;
- pedir;
- traer;
- dar;
- imperatives.

---

# ACT IV — The Pattern
**Estimated time:** 75–90 min

Deaths of León and Gaspar become known.

Mateo sees a pattern.

Inés sees money.

The player is encouraged to suspect the Order.

Then evidence begins contradicting the single-killer hypothesis.

León’s workshop:

No foreign footprints.

No cut mechanism.

Safety valve manually tied open.

Key question:

> Did someone sabotage the machine, or did León override the safety system himself?

Witness statements show León had said:

> “If I reduce the pressure again, the demonstration fails.”

This is not confession.

It is evidence of intent.

Spanish:

- imperfecto;
- indefinido vs imperfecto;
- cuando;
- mientras;
- soler;
- estar + gerund.

---

# ACT V — The Man from a Dead World
**Estimated time:** 60–75 min

Elias appears at Monte Ciego.

At first everyone assumes:

- madman;
- prophet;
- spy;
- demon.

He possesses objects impossible to manufacture locally.

He calls El Índice:

> “a language model with administrative survivors.”

Nobody understands.

His explanation develops gradually.

He never gives a lecture longer than a few sentences.

His key idea:

> “The machine did not misunderstand reality. We misunderstood what the machine understood.”

This act introduces the philosophical core.

Spanish:

- conditional;
- si clauses;
- habría;
- podría;
- debería;
- subjunctive basics.

---

# ACT VI — The Archive Beneath the Monastery
**Estimated time:** 90–120 min

All three protagonists converge on Santa Lucerna.

A hidden crypt opens.

The player reaches El Índice.

The interface is textual.

The machine can be queried.

It gives frighteningly plausible answers.

Example:

Player asks:

> What happens if mechanical printing becomes universal?

El Índice produces patterns:

- propaganda;
- sectarian conflict;
- administrative destabilization;
- mass mobilization.

Elias points out:

> “Ask it what happens on an ordinary Tuesday after printing becomes universal.”

The system struggles.

This is the revelation.

Its archive contains crises.

Not ordinary continuity.

The Order mistook a model of recorded human significance for a model of the physical world.

---

# ACT VII — The Council of Silence
**Estimated time:** 90 min

Valdora enters crisis.

The Bishop wants emergency authority.

Guilds want confiscation of forbidden workshops.

Students in Miralba riot.

Workers in Ferraza defend machinery.

Grain deliveries from San Vélaro stop.

Every faction has a theory.

Every faction is partly right.

The Order calls a secret council.

Participants:

- Mateo;
- Inés;
- Elias;
- Ysabel;
- Bishop Veyra;
- Judge Beatriz;
- Esteban;
- guild representative;
- military commander.

The player must present a final model of events.

Not merely name a murderer.

They must distinguish:

```text
verified facts
probable causes
institutional acts
false associations
unresolved uncertainty
```

---

# 17. Major quests

## MQ01 — El cuerpo bajo la torre
Investigate Tomás.

## MQ02 — Lo que dice el sello
Understand legal confiscation.

## MQ03 — El cuaderno perdido
Find Tomás’s notebook.

## MQ04 — Precio de copia
Trace printers’ economic motive.

## MQ05 — Presión
Investigate León’s death.

## MQ06 — Lo limpio y lo rentable
Investigate Gaspar poisoning.

## MQ07 — El hombre que no existe
Find Elias.

## MQ08 — La sala sin santos
Enter hidden archive.

## MQ09 — Preguntar mal
Discover El Índice’s epistemic limitation.

## MQ10 — La verdad oficial
Prevent or enable a political purge.

## MQ11 — El Consejo del Silencio
Final investigation and choice.

---

# 18. Important side quests

## SQ01 — Pan de ayer

A baker sells stale bread during shortage.

Player can:

- threaten;
- bargain;
- investigate supply problem.

Lesson:

price ≠ greed automatically.

Cause is disrupted grain route.

Spanish:

prices, quantities, complaints.

---

## SQ02 — Aire para los muertos

Miners want a mechanical ventilation fan.

Guild inspectors ban it as unlicensed machinery.

Without it miners die slowly.

If player approves it:

production rises, mine owners extend shifts.

Technology saves workers and enables exploitation simultaneously.

---

## SQ03 — El niño que confesó

A teenager confesses to stealing a relic.

Mateo can detect that the confession contains language copied from the guard’s accusation.

Lesson:

confession can be an echo of authority rather than independent evidence.

---

## SQ04 — La carta verdadera

A forged letter contains true information.

Player must decide:

Can false provenance carry a true proposition?

Gameplay classification:

```text
document authenticity = false
claim accuracy = true
institutional validity = false
```

---

## SQ05 — La máquina de Simón

Simón’s pressure engine works.

Workers ask the player to destroy it.

Owner wants to scale production.

The Order wants it banned.

There is no clean choice.

---

## SQ06 — El santo eléctrico

Villagers worship an ancient capacitor assembly because it produces sparks.

The Church wants it destroyed.

Elias identifies it as harmless equipment.

But pilgrimage income supports the village.

Destroying superstition may destroy the local economy.

---

# 19. The Order's internal logic

The Order does not ban all technology.

It classifies technologies into five levels.

## White
Local, non-scaling.

Examples:

- plow;
- hand mill;
- simple lens.

## Amber
Can improve productivity.

Examples:

- mechanical loom;
- improved press.

## Red
Scales communication or production.

Examples:

- cheap printing;
- precision engine;
- long-range signaling.

## Black
Automates decision or administration.

Examples:

- computation;
- predictive governance;
- autonomous logistics.

## Ash
Technologies the Order believes directly connected to the old collapse.

Most members have never seen an Ash-class device.

---

# 20. Philosophical conflict

There are four competing positions.

## Position A — The Order

Human societies cannot control acceleration.

Therefore knowledge must be rationed.

Strength:

Recognizes real systemic risk.

Weakness:

Turns uncertain prediction into permanent authority.

---

## Position B — The Humanists

Knowledge should circulate freely.

Strength:

Innovation, accountability, decentralized learning.

Weakness:

Underestimates coordination failures and power concentration.

---

## Position C — Elias

Technology must progress, but institutional authority must never be delegated to predictive systems.

Strength:

Understands performative feedback loops.

Weakness:

Assumes his own historical interpretation is uniquely valid.

---

## Position D — Inés

Nobody should monopolize knowledge.

Strength:

Recognizes that monopoly is often the real engine of repression.

Weakness:

Markets do not automatically produce moral outcomes.

---

# 21. Final revelation about El Índice

El Índice contains no secret statement saying:

> “Technology destroys civilization.”

Instead there are thousands of generated analyses.

Centuries ago the founding monks asked:

> “Which developments most often precede systemic collapse?”

The responses repeatedly mentioned:

- scalable communication;
- automated logistics;
- predictive governance;
- financial abstraction;
- industrial concentration;
- autonomous weapons.

The monks transformed:

```text
association
```

into:

```text
warning
```

then:

```text
warning
```

into:

```text
doctrine
```

then:

```text
doctrine
```

into:

```text
law
```

then:

```text
law
```

into:

```text
social reality
```

This chain is the core mystery.

---

# 22. Why the murders matter philosophically

The game begins with:

> Who killed Tomás?

It ends with:

> What kind of statement is “Tomás was killed by the Order”?

Possible interpretations:

1. factually false if referring to direct physical causation;
2. politically plausible because the Order created the system of suppression;
3. legally useful;
4. morally incomplete;
5. strategically dangerous.

The player learns that a proposition can be:

- false in one sense;
- useful in another;
- causally powerful in a third.

---

# 23. Final choices

There is no three-button morality menu.

The player must construct a conclusion from classified claims.

The final decision is derived from evidence and dialogue.

Possible endings:

---

## ENDING A — Destroy El Índice

Result:

The Order collapses.

Forbidden research spreads.

Short-term:

- intellectual explosion;
- guild conflict;
- political instability.

Long-term:

unknown.

Elias calls this freedom.

Ysabel calls it amnesia.

---

## ENDING B — Preserve the Order

El Índice remains secret.

Suppression continues.

Some reforms occur.

The province stabilizes.

Ferraza’s industrial experiments are restricted.

Deaths from poverty continue quietly.

Final line idea:

> The year ended peacefully. Historians had little to write about it.

This is deliberately ambiguous because El Índice would interpret the silence as success.

---

## ENDING C — Open the Archive

El Índice becomes public.

Anyone can query it.

This initially appears democratic.

Then political factions selectively quote its outputs.

The machine becomes a source of competing authority.

The problem changes rather than disappears.

---

## ENDING D — The Evidence Charter

Hardest ending.

Requires high evidence quality and several optional quests.

The player creates a legal framework:

1. El Índice may advise.
2. It cannot issue binding declarations.
3. Predictions must include uncertainty and alternative interpretations.
4. Canonical decisions require independent evidence.
5. Technological restrictions require explicit review and expiration dates.
6. Institutional acts must name responsible human authority.

This mirrors the game architecture:

```text
model proposes
→ humans / deterministic rules verify
→ institution acts
```

This is not portrayed as utopia.

It is simply the least dishonest system available.

---

# 24. Character endings

## Mateo

Best arc:

Accepts that procedure cannot manufacture justice.

Remains in the Tribunal but limits its authority.

Dark arc:

Becomes head of a “rationalized” Inquisition more efficient than the old one.

---

## Inés

Best arc:

Builds a network distributing books and medical knowledge.

Dark arc:

Turns forbidden knowledge into the most profitable monopoly in the province.

---

## Elias

Best arc:

Admits uncertainty about his own civilization’s collapse.

Chooses to teach rather than command.

Dark arc:

Becomes the new oracle because people trust the man who “has seen the future”.

---

# 25. Map-based pacing

Recommended critical route:

```text
Santa Lucerna
↓
Valdora
↓
Cárdena / Puente Seco
↓
Miralba
↓
Ferraza
↓
Monte Ciego
↓
Santa Lucerna crypt
↓
Valdora finale
```

Optional branches:

```text
San Vélaro
Minas de Bruma
Marjal Negro
minor villages
guild workshops
smuggler camps
ancient ruins
```

---

# 26. Map node specification

| ID | Name | X | Y | Type | Major use |
|---|---|---:|---:|---|---|
| LOC01 | Santa Lucerna | 52 | 39 | monastery | opening / archive |
| LOC02 | Valdora | 63 | 66 | capital | politics / tribunal |
| LOC03 | Miralba | 105 | 48 | university city | medicine / books |
| LOC04 | Ferraza | 114 | 78 | industrial city | machinery / workers |
| LOC05 | Cárdena | 126 | 105 | port | Inés / smuggling |
| LOC06 | Puente Seco | 103 | 68 | customs town | toll / witnesses |
| LOC07 | San Vélaro | 33 | 26 | northern town | grain crisis |
| LOC08 | Minas de Bruma | 92 | 22 | mine | ventilation quest |
| LOC09 | Monte Ciego | 48 | 8 | mountain ruin | Elias arrival |
| LOC10 | Marjal Negro | 39 | 94 | marsh | optional relic zone |
| LOC11 | Venta del Perro Negro | 74 | 59 | inn | recurring dialogue hub |
| LOC12 | Granja Arce | 46 | 55 | farm | food / witness |
| LOC13 | Taller Rojo | 117 | 73 | workshop | León investigation |
| LOC14 | Archivo Episcopal | 66 | 62 | archive | documents |
| LOC15 | Hospital de Miralba | 107 | 51 | hospital | Gaspar / Leonor |
| LOC16 | Casa de Impresores | 71 | 70 | guildhouse | Tomás motive |
| LOC17 | Campamento del Puente | 93 | 82 | smuggler camp | Inés network |
| LOC18 | Torre del Relé | 50 | 10 | ruin | parallel-world event |

---

# 27. Required city texture

Each city should have a distinct social vocabulary.

## Valdora

Words:

```text
tribunal
permiso
decreto
archivo
impuesto
mercado
guardia
barrio
```

## Cárdena

```text
muelle
barco
carga
precio
contrabando
almacén
aduana
deuda
```

## Miralba

```text
universidad
profesor
estudiante
libro
experimento
hospital
prueba
teoría
```

## Ferraza

```text
fábrica
taller
hierro
máquina
rueda
presión
trabajador
turno
```

This lets geography drive Spanish vocabulary.

---

# 28. Quest design rule

Every major quest should contain at least:

```text
1 physical observation
1 testimony
1 ambiguous interpretation
1 institutional statement
1 Spanish production task
1 opportunity to be wrong without immediate failure
```

---

# 29. Dialogue philosophy

Claude receives:

```text
what NPC observed
what NPC inferred
what NPC believes
what NPC wants
what NPC is hiding
what NPC is authorized to do
```

These must remain separate.

Example:

Gabriel:

```text
OBSERVED:
heard horse

INFERRED:
someone left monastery

BELIEVES:
visitor was smuggler

WANTS:
avoid investigation

SECRET:
stole wine

AUTHORITY:
none
```

His dialogue can therefore be honest and still misleading.

---

# 30. Example philosophical dialogue — Ysabel

Player:

> ¿El Índice sabe lo que va a pasar?

Ysabel:

> Saber es una palabra cómoda. El Índice recuerda millones de cosas que nosotros no recordamos y encuentra semejanzas que nosotros no vemos. Eso no significa que vea el futuro. Significa que nosotros llevamos siglos comportándonos como si lo viera.

Player:

> Entonces, ¿por qué obedecerlo?

Ysabel:

> Porque cuando una predicción equivocada puede matar a diez personas y una predicción ignorada puede matar a diez millones, la prudencia empieza a parecerse mucho al miedo.

---

# 31. Example dialogue — Elias

> En mi mundo empezamos usando sistemas para recomendar decisiones. Después les permitimos aprobarlas. Luego nadie recordaba quién había decidido realmente. Cuando algo salía mal, todos podían señalar al modelo y decir: “Eso era lo más probable.” La probabilidad se convirtió en una forma de inocencia.

---

# 32. Example dialogue — Inés

Mateo:

> Robas libros prohibidos.

Inés:

> No. Transporto mercancía que el Estado ha decidido hacer muy cara.

Mateo:

> Eso se llama contrabando.

Inés:

> Ves. Ya estamos de acuerdo. El idioma funciona.

---

# 33. Example dialogue — Beatriz

> Un documento falso puede producir una detención verdadera. Una acusación falsa puede destruir un matrimonio verdadero. Una frontera imaginaria puede hacer que soldados reales maten a personas reales. No confunda “inventado” con “sin efectos”, inquisidor.

---

# 34. Example black humour

At Puente Seco:

Guard:

> El puente está cerrado.

Inés:

> ¿Por qué?

Guard:

> Por seguridad.

Inés:

> ¿De quién?

Guard:

> Del puente.

---

# 35. The political crisis in Act VII

Three events occur nearly simultaneously:

1. Grain convoy from San Vélaro is delayed.
2. Ferraza workers occupy a workshop.
3. A forged Order document claims Miralba will be purged.

The city assumes coordinated rebellion.

It is not coordinated.

But official reaction can make it coordinated.

This is the final semiotic lesson:

```text
false description
→ institutional response
→ people react to response
→ description becomes true
```

---

# 36. Final council gameplay

The player must place claims into five columns:

```text
OBSERVED
REPORTED
INFERRED
DECLARED
UNRESOLVED
```

Example:

```text
"León was threatened by the Order"
→ OBSERVED/REPORTED, depending source

"Therefore the Order killed León"
→ INFERRED

"León's death is officially classified as sabotage"
→ DECLARED

"Who tied the safety valve?"
→ can become OBSERVED if evidence found
```

Wrong classification changes available endings.

---

# 37. Why this world supports the language game

The setting allows modern vocabulary without breaking medieval aesthetics.

Examples:

```text
sistema
señal
red
proceso
presión
energía
memoria
registro
archivo
código
modelo
riesgo
evidencia
transmisión
mecanismo
autoridad
```

These words belong naturally to:

- monasteries;
- courts;
- workshops;
- trade;
- philosophy.

The player can therefore learn useful modern Spanish without conversations about smartphones or airports.

---

# 38. Canonical tone rules

Writers / Claude must follow:

1. No chosen-one prophecy.
2. No purely evil faction.
3. No exposition longer than necessary.
4. Smart characters may be wrong.
5. Poor characters understand incentives perfectly well.
6. Institutions have internal factions.
7. Violence changes later behaviour.
8. Technology creates both benefits and displaced interests.
9. Knowledge does not equal wisdom.
10. Cynicism is not automatically intelligence.
11. A correct fact can support a bad interpretation.
12. A false statement can have real consequences.
13. Most days contain no revelation.
14. The world should often feel tired rather than epic.

---

# 39. Canonical mystery summary

For implementation only:

```text
Tomás:
murdered by Printers Guild agent.

León:
accidental death after bypassing safety mechanism.

Gaspar:
murdered by Apothecaries Guild leader.

Beltrán:
murdered by Last Light operative.

Esteban:
not murdered; voluntarily joined the Order.

Order:
responsible for suppression, threats and one direct murder.

El Índice:
ancient predictive language/archive system, not oracle.

Founding error:
human records were mistaken for direct representation of world dynamics.

Elias's world:
collapsed partly because predictive systems gained institutional authority
and their outputs became performative feedback loops.

Final conflict:
not technology vs religion,
but how societies translate information into authority and action.
```

---

# 40. Implementation priority

Build scenario content in this order:

```text
1. Santa Lucerna
2. Tomás investigation
3. Valdora tribunal
4. Cárdena / Inés
5. Miralba / Gaspar
6. Ferraza / León
7. Monte Ciego / Elias
8. hidden archive
9. political crisis
10. final council
11. optional northern/mining/marsh quests
```

The game should be fully playable through step 3 before the rest of the world is populated.

---

# 41. Final design statement

The mystery is not ultimately:

> “Who killed the monks?”

It is:

> “What kind of thing is a fact once people, institutions and machines begin acting on interpretations of it?”

The player begins by examining a corpse.

They end by deciding whether civilization should trust:

- authority;
- markets;
- machines;
- experts;
- open knowledge;
- or procedures that force all of them to expose their uncertainty.

There is no perfect answer.

That is the point.

# 42. Optional parallel case catalog (2026-10-05)

The user's expansion adds 12 original cases of nine quests each, with 108 evidence
artifacts, 108 battle encounters, 108 evidence-inference puzzles and 12 acrostics.
See docs/SIDE_INVESTIGATIONS.md and game/content/scenario/side_investigations.json
for every title, observation, false interpretation, supported answer and dependency.

Cases concern a reused census; displaced bell hours; water rights; displaced residents'
names; workshop bestiary symbols; optical claims; port weights; hospital denominators;
guild standards; private correspondence; mine ventilation; and grain categories.
They occupy existing locations and do not rewrite the central deaths, Esteban's
disappearance, El Índice or the main ending. Original SQ01-SQ06 remain distinct.
The ventilation case complements the existing mining quest without replacing its facts.

Branches have independent entries and parallel clue paths that rejoin. Twelve optional
comparisons link completed cases. Each ending offers public publication or protected
disclosure, with local consequences. Violence grants custody only, never establishes
truth. Peaceful access and retreat preserve the ability to complete an investigation.

Every quest includes Spanish practice through model, supported production, independent
production and delayed recall. Blocks progress 1,1,2,2,3,4,5,6,7, subject to actual prior
mastery. All advanced tasks remain unavailable until their language prerequisites are
consolidated. Rule-based cipher solutions require no outside literary knowledge.

Status (updated 2026-10-08): integrated at runtime on the province map. Concluded
cases, the twelve optional comparisons (once both cases are concluded) and the chosen
publication or protected copy appear as notebook pages; the chosen outcome is shown at
the case's location and passed to conversations as a flag. The comparisons are pages to
read, not tasks. Combat values are unplaytested.
Full optional completion is outside the original campaign-duration estimate.

# 43. Fragmented souls and ghost knights (2026-10-05)

The user-requested verbal/semiotic adversary manifests as eight ghost knight personas.
Working name: La Frase Inconclusa (the Unfinished Sentence). Its aim is to turn an
interpretation into an unquestionable obligation. These apparitions do not change
El Índice into an oracle or rewrite the canonical causes of the main deaths. Their
observable actions are real in the expanded scenario; the metaphysics of souls,
apparitions and relic-mediated voices remains open as in section 6.

The Glosador alters labels; the Notario challenges provenance; the Anacronista shifts
notices; the Corista multiplies rumors; the Tasador intercepts unclaimed fragments;
the Censor obscures copies; the Caballero del Siempre absolutizes promises; and the
Silogista inserts unsupported causal links. Their traces and local consequences can
alter optional scene order, witness access and comparisons, never immutable past facts.
Each has a distinct target policy, appearance, Spanish counter and battle tactic.

Six highest-rank assemblies house Alda, Iria, Nerio, Beltrán, Sira and Daro: respectively
the intact witness armor, open-hand vestments, distant-voices bow, revisable-oath sword,
unfinished reader's crown and free-roads mantle. Their four components preserve memories.
The player must persuade the soul in Spanish, not merely complete a shopping list.
Each has a particular fear, competing arguments and ordered teaching prerequisites.

Twenty-four reward overlays attach components to the SX investigations without replacing
or consuming their AX evidence. Both peaceful and combat custody routes preserve these
rewards. Ghost victories never establish truth or forge consent. The soul artifacts
offer additional counters, but no case requires owning one to remain solvable.

Canonical expansion data: game/content/scenario/equipment.json and ghost_knights.json.
Author guide: docs/EQUIPMENT_AND_GHOST_KNIGHTS.md. Status (updated 2026-10-07): equipment,
soul dialogues, knight strategy and simultaneous world turns are integrated at runtime.
The per-set soul actions are not yet distinct in play and balance is unplaytested.

## Opening investigation staging and strategic economy (2026-10-05)

The opening implementation expands the six Act I clues without changing their cause.
The first guided observation is travel food. Subsequent physical inspections cover the
broken brass tube, blood inside the tower, scraped boot and the notebook's absence.
Recording an absence does not recover the notebook or bypass Inés's later investigation.

A local preservation order is available after Lucio communicates the community's account:
the abbot orders Tomás's belongings preserved and transfers recorded. This is a custody
document, not proof of suicide and not the bishop's later heresy/confiscation decision.
Authored dialogue extensions reserve Gabriel's denial, horse testimony and irrelevant
wine theft, plus a visiting Leonor's clinical report. Leonor's home remains Miralba.
These reserved conversations require their own grounding and runtime integration before
being offered to the player; author-only reliability labels must never leak to the UI.

The strategic economy follows the user's Heroes III requirement: gold, wood, ore,
mercury, sulfur, crystal and gems fund buildings, recruitment, troop upgrades and
artifacts. Mines and contested resource sites make map travel and army decisions
material to the narrative. Food and medical supplies are additional consumables.
All purchases require supported Spanish production at the learner's current block.
The mechanical contract is in MASTER_BUILD_SPEC section 12; the implementation gates
still apply, and authored economic requirements are not an implemented economy.
### Opening road encounter

After the first recorded clue, the Venta del Perro Negro offers an optional encounter
against five road bandits obstructing deliveries. The prototype escort starts with
eight militia and four archers. Winning releases 60 gold as a local reward; retreat
and defeat preserve only surviving troops. This encounter is unrelated to the identity
of Tomás's killer and supplies no evidence about the Order. It provides the required
opening combat without rewriting the canonical death or later revelations.
### Three-hero development slice

The small development map may stage Mateo, Inés and Elias together to verify independent
movement, armies and inventory before the campaign map exists. This is a mechanical
fixture, not an early canonical arrival of Elias or a replacement for Inés's Act III
introduction. The full campaign must retain Cárdena for Inés and Monte Ciego for Elias.
The prototype starts Mateo with militia/archers, Inés with archers and Elias with two
rare relic sentinels. These escorts do not reveal the truth of El Índice to other NPCs.
### Province map travel staging

The authored 160x120 map preserves all eighteen location coordinates from section 26.
Its northern ridge has one pass at (49,14). The travel checkpoint opens after the
verified opening reconstruction; this does not introduce Elias, who still requires
his Act V scene. Ines remains locked until her Act III introduction in Cardena.
Seven resource-site placements support the later economy; placing a mine does not
by itself implement ownership, income or purchases. Public POI descriptions disclose
no murder solutions or concealed machinery beneath the monastery.