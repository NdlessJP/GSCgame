# Ashen Vanguard

A 2D **party-based real-time RPG** prototype built with **Godot 4.3** and **typed GDScript**.
Six original heroes fight through three-wave quests on a side-view battlefield: units
auto-attack on timers while the player spends an **Arts gauge**, a **Break meter** and
**equipment actives** to win.

Everything is original: original names, original UI layout, original placeholder visuals
(coloured geometric silhouettes drawn with the engine's drawing API — **no imported art**,
no external assets, no paid dependencies, no network calls).

---

## 1. Requirements

| | |
| --- | --- |
| Godot version | **4.3-stable or newer** (4.3 was used for development and testing) |
| Renderer | GL Compatibility (set in `project.godot`, so it runs on low-end/software GPUs) |
| Platform | Desktop-first, landscape, mouse driven; keyboard shortcuts are optional |
| Dependencies | None. No add-ons, no asset packs, no API keys, no network access |

Download Godot 4.3+ from <https://godotengine.org/download> (the standard build is enough).

## 2. How to run

**From the editor**

1. Open Godot → *Import* → select `project.godot` in this folder.
2. Press **F5** (Run Project). The main scene is `res://scenes/main_menu/main_menu.tscn`.

**From the command line**

```bash
# Headless smoke test (starts the game, no window)
godot --headless --path .

# Run the automated test suite (165 checks)
godot --headless --path . --import          # refresh the class cache first
godot --headless --path . res://tests/test_runner.tscn
```

The project must be re-imported (`--import`) after adding a new `class_name` script so
Godot's global class cache picks it up.

## 3. The game loop

```
Main Menu ──► Party Setup ──► Quest Board ──► Battle (3 waves) ──► Results ──┐
   ▲             ▲              ▲                  │   ▲                     │
   └─────────────┴──────────────┴──────────────────┘   └─────────────────────┘
        (Party & Gear / Quest Board are reachable from the menu and the results screen)
```

* **Main Menu** – start, quest board, party & gear, controls, volume, reset profile, quit.
* **Party & Gear** – roster, 4 party slots, stats, abilities, equipment, level & XP.
* **Quest Board** – three quests, unlock state, recommended level, rewards, encounter preview.
* **Battle** – preparation → wave 1 → wave transition → wave 2 → wave transition → wave 3 → victory/defeat.
* **Results** – XP, sigil shards, item drops, level-ups, a **battle report** (time, damage dealt and taken, abilities used, breaks triggered, enemies defeated) and buttons to party setup / retry / quest board / menu.
* **Pause menu** – resume, retry, return to quest board.

## 4. Controls

Everything is fully playable with the mouse. The keyboard shortcuts are optional
shortcuts for fast play.

| Action | Mouse | Keyboard |
| --- | --- | --- |
| Select ally in party screen | Click roster entry | — |
| Assign ally to party slot | *Assign to party* buttons | — |
| Equip / unequip | Slot drop-downs | — |
| Start quest | *Start Quest* | — |
| Set the party's preferred target | Click an enemy | `T` cycles to the next living enemy |
| Skill of party member 1–4 | *Skill* button on that member's panel | `Q` `W` `E` `R` |
| Arts of party member 1–4 | *Arts 100* button | `A` `S` `D` `F` |
| True Arts of party member 1–4 | *True 200* button | `Z` `X` `C` `V` |
| Equipment actives of party member 1 | The three equipment buttons of member 1 | `1` `2` `3` |
| Pause | *Pause* button | `P` or `Esc` |
| Battle speed | *1x / 2x / 3x* button in the top bar | — |
| Resume / retry / quit | Pause menu buttons | — |

## 5. Combat rules

### 5.1 Battlefield and turn flow

* Side-view battlefield: **allies on the left, enemies on the right**.
* Every living unit runs on its own timer: basic attacks fire automatically, abilities
  have their own cooldowns, and enemy AI decides when to use its skills.
* Clicking an enemy sets the **party's preferred target**; when that target dies the party
  automatically retargets the next living enemy.
* Defeated units stop acting, stop being targetable, and are drawn as grey silhouettes
  with a red cross.

### 5.2 Battle state machine

`PREPARATION → COMBAT → WAVE_TRANSITION → COMBAT → … → VICTORY | DEFEAT`
(plus `PAUSED`, which freezes the whole simulation).

* Victory = **all waves cleared**. Defeat = **the whole party is down**.
* After the battle ends no further actions are processed and no rewards are granted
  twice — rewards are issued exactly once per completed battle through a battle token.

### 5.3 Damage formula

All damage flows through `scripts/battle/damage_calculator.gd`. Every constant lives in
`scripts/core/balance_config.gd`.

```
base      = flat_amount + stat * power / 100      # stat = ATK (physical) or MAG (magical)
mitigated = base * (100 / (100 + target_defense))  # physical uses DEF, magical uses MAG DEF
                                                        # TRUE damage ignores mitigation
mitigated *= element_multiplier(attacker, defender)   # 1.5 advantage / 1.0 neutral
mitigated *= 1.6        # only on a critical hit (8 % base crit rate)
mitigated *= 1.25       # only when the target is Broken
mitigated *= (1 - damage_reduction)   # optional target-side reduction status
final     = max(1, mitigated)
```

Shields absorb damage **before** HP is lost; the overflow continues to HP.
Lifesteal heals the attacker by a percentage of the HP actually lost.

### 5.4 Element table (complete)

`scripts/core/elements.gd` defines the full 5×5 table; every ordered pair has a value.

| attacker \ defender | Fire | Earth | Water | Light | Dark |
| --- | --- | --- | --- | --- | --- |
| **Fire**  | 1.0 | **1.5** | 1.0 | 1.0 | 1.0 |
| **Earth** | 1.0 | 1.0 | **1.5** | 1.0 | 1.0 |
| **Water** | **1.5** | 1.0 | 1.0 | 1.0 | 1.0 |
| **Light** | 1.0 | 1.0 | 1.0 | 1.0 | **1.5** |
| **Dark**  | 1.0 | 1.0 | 1.0 | **1.5** | 1.0 |

### 5.5 Arts gauge

* Gauge range **0 – 200**.
* **Arts costs exactly 100**, **True Arts costs exactly 200**; both are configurable.
* Gauge is generated by basic attacks (12), by Skills (15) and by designated support
  effects (per-ability `arts_generated`).
* A button is disabled (and the cost is refused) when the gauge is insufficient, so
  rapid clicking cannot bypass the cost.

### 5.6 Break meter (enemies only)

* Enemies have a break meter; heroes do not.
* Attacks add break damage (basic attacks add 5 on top of the ability value).
* When the meter reaches zero the enemy becomes **Broken**: it stops acting and takes
  **×1.25 damage**.
* Broken lasts 4 s, then the meter **resets to zero** and the enemy acts again.
* The boss has a prominent HP bar **and** break bar at the top of the screen.

### 5.7 Statuses

Statuses live in `scripts/units/status_instance.gd` and are driven by
`scripts/data/status_def.gd`. Each status has a duration, a source, a stacking /
refresh policy, a stat modification and optional periodic (damage-over-time) ticks.

Shipped examples: **Venom** (damage over time, stacks to 3), **Stunned** (target cannot
act), **Might** (+25 % attack), **Sundered** (−30 % defense), **Wane** (−30 % magic
defense), **Bulwark** (+40 % defense), **Ward** (absorbs damage), **Resonance** (arts
generation), **Renewal** (regeneration), **Enraged** (boss self-buff).

When a status expires every stat modifier it applied is removed, so no buff or debuff
leaks past its duration (covered by an automated test).

### 5.8 Waves

* A quest is a list of waves; every wave spawns a set of enemies from `WaveDef`.
* **Every wave carries its own difficulty ramp.** `WaveDef.enemy_level` raises the level
  the enemies are spawned at and `WaveDef.stat_scale` multiplies their stats, so a quest
  gets harder from wave to wave even when it reuses the same enemies. The scaling lives
  in the runtime state (`UnitState.stat_multiplier`), never in the shared enemy
  definition, so no resource is ever mutated.
* Between waves the controller **cleans up** dead enemies, projectiles and pending
  actions.
* **Party HP and the Arts gauge carry over between waves.**
* **Character and equipment cooldowns also carry over** (they are per-battle timers and
  are not reset by a wave change); combat timers and pending actions are reset.

### 5.9 Reading the battlefield

* The top bar shows the quest, the current wave, the battle state, the **current
  preferred target** (with the elements that hit it harder) and a **battle speed toggle**
  (1x / 2x / 3x). The speed only multiplies the battle clock, so nothing else in the
  game is affected.
* A **Controls** button (main menu) and a **?** button (battle) open the same overlay
  that lists every mouse action and keyboard shortcut.
* Every party member's panel shows the **name of the ability** on the button, with its
  cost or remaining cooldown underneath, and a tooltip with the full description.
* Abilities with a wind-up draw a **pulsing telegraph ring** around the caster and
  print a warning, so a party wide attack can be dodged or interrupted.
* The boss has a dedicated panel with its HP bar **and** its break meter.

### 5.10 Boss

`Aurelith, the Ashen Warden` (Fire) has:

* a basic attack,
* a **telegraphed party-wide attack** (*Cataclysm*, announced with a red warning strip),
* a self-buff (*Iron Bulwark*),
* a **one-time phase change below 50 % HP** (*Ashen Ascension*) that unlocks two new
  attacks (*Eruption*, *Magma Chains*),
* a meaningful **Break window** (the phase change grants a large amount of break damage,
  so a well-timed burst can break it).

The phase change can only trigger once per battle — verified by an automated test.

### 5.11 Sound

The project ships **without imported audio**. Every sound effect is synthesised at
start-up into an `AudioStreamWAV` by `scripts/ui/audio_director.gd` (the `Audio`
autoload): hits, critical hits, breaks, healing, shields, the boss warning, wave
changes and the victory / defeat stingers. Rapid identical sounds are throttled so a
burst of hits does not turn into noise.

## 6. Content

### 6.1 Heroes (6, all playable)

| Hero | Element | Role | Notes |
| --- | --- | --- | --- |
| Kael Vondar | Fire | Vanguard | Highest HP/attack, frontline basics |
| Seraphine Quill | Light | Cleric | Healing and shield support |
| Torvald Grim | Earth | Guardian | Very high HP, defensive basics |
| Lysa Venne | Water | Arcanist | Magical damage, arts generation |
| Rune Ashmaw | Dark | Saboteur | Break-focused, arts generation |
| Brennan Cole | Fire | Ranger | Balanced, fast basics |

### 6.2 Enemies

`Cinder Wisp` (Fire), `Marsh Slime` (Water), `Stone Husk` (Earth), `Night Shade` (Dark)
and the boss `Aurelith, the Ashen Warden` (Fire).

Enemy AI picks a target by preference (`FOCUS`, `ROTATE` — the default spreads damage
across the party — or `WEAKEST`) and only uses an ability when it is off cooldown.

### 6.3 Quests

| Quest | Level | Waves |
| --- | --- | --- |
| Cinder Road | 1 | Wisp swarm, husk wall |
| Sunken Causeway | 3 | Slimes and shades |
| The Ashen Vault | 5 | Mixed waves, then **Aurelith** |

Quest 2 unlocks after quest 1 and quest 3 after quest 2. (The prototype keeps a
`U` shortcut on the quest board that unlocks every quest for testing.)

### 6.4 Equipment

11 items in three categories — **Attack**, **Defense**, **Support** — each character has
three slots (Offence / Guard / Auxiliary) that only accept the matching category.

Every item has passive stat bonuses **and** an active ability with its own cooldown
(e.g. *Twin Fangs* → *Twin Fang*, *Resonance Bell* → *Resonant Chime*).
Item ownership is tracked with **instance ids**, so one physical copy cannot be equipped
twice; you need two copies to equip two characters.

## 7. Progression and saving

* Winning a quest grants **XP**, **sigil shards** (soft currency) and sometimes an item.
* XP curve: `xp_to_next = 80 + 60 * (level - 1)`.
* Character stats grow per level using the growth values in each `CharacterDef`.
* The save file is JSON in the Godot **user data directory**
  (`user://ashen_vanguard_save.json`), with a **schema version**.
* Saved: currency, character levels/XP, owned equipment, party composition and
  assignments, quest unlocks and completions, and the master volume.
* **Not saved:** temporary battle state (HP, cooldowns, gauges, wave progress).
* A missing or corrupt save is handled gracefully: the file is quarantined (renamed) and
  a fresh profile is started; invalid ids are validated and dropped on load.

## 8. Project layout

```
project.godot            # main scene, autoload `Game`, 1280x720 GL Compatibility
scenes/                  # main_menu, party, quests, battle, results
scripts/
  core/                  # elements, balance_config, game_database, game_state, game (autoload)
  ui/audio_director.gd   # procedural sound effects (autoload `Audio`)
  data/                  # Resource definitions (AbilityDef, StatusDef, CharacterDef, ...)
  units/                 # runtime state: UnitState, StatusInstance, Unit view
  battle/                # battle_controller (state machine), damage_calculator,
                         #   ability_executor, enemy_ai, pending_action
  effects/               # effect_applier (pure effect execution)
  inventory/             # item instances, ownership and equip rules
  progression/           # XP curve and stat growth
  saving/                # save_service (JSON, schema version, corrupt quarantine)
  ui/                    # menus, battle HUD, unit panels, floating text, projectiles,
                         #   help overlay
resources/               # generated .tres content (characters, enemies, items, quests, ...)
assets/placeholders/     # placeholder visual notes and reference art
tools/                   # build_content.gd (content generator), screenshot_tour.gd
tests/                   # automated test suite (see below)
```

### Architecture rules

* **Definitions are Resources, runtime state is separate.** A `CharacterDef` is never
  mutated for HP, cooldowns or buffs; `UnitState` holds all mutable combat state.
* **Single responsibilities**: `DamageCalculator` (maths), `EffectApplier` (apply
  effects), `AbilityExecutor` (validate cost/cooldown/targets, then execute),
  `EnemyAI` (decisions only), `BattleController` (state machine, clock, waves, signals,
  rewards), `Game` (profile, party, inventory, rewards).
* **Combat → UI communication uses signals** (`battle_reset`, `unit_changed`,
  `hp_changed`, `arts_changed`, `ability_used`, `status_applied`, `status_expired`,
  `damage_dealt`, `healed`, `unit_died`, `break_changed`, `boss_phase_changed`,
  `wave_started`, `battle_finished`, `reward_granted`, …). The UI never reaches into
  the controller's internals.
* No giant scripts and no global singleton besides the single `Game` autoload.

## 9. Adding content

The fastest path is the content generator: **`tools/build_content.gd`** writes every
`.tres` file. Add a block to the relevant section and re-run:

```bash
godot --headless --path . --script res://tools/build_content.gd
```

* **New hero** – add a `_character(...)` block with a stable id, display name, element,
  role, base stats, growth, basic attack config, skill/arts/true-arts ids and the
  accepted equipment categories. The `CharacterDef` resource is the only place hero
  data lives.
* **New ability** – add an `_ability(...)` block: id, name, damage type, element,
  power, windup, cooldown, arts cost and generation, and a list of `EffectDef`
  entries (single target or AoE damage, healing, shield, buffs, defense reduction,
  arts generation, break damage).
* **New status** – add a `_status(...)` block: duration, stacking policy, stat
  modifiers, periodic ticks. Existing examples: venom, stun, might, sundered, wane,
  bulwark, ward, resonance, renewal, enraged.
* **New item** – add an `_equipment(...)` block with a category, slot restrictions,
  passive stat bonuses and an active ability with its own cooldown.
* **New enemy** – add an `_enemy(...)` block: stats, basic attack config, ability list
  with cooldowns, target preference and, for a boss, `is_boss` plus a phase-change
  threshold.
* **New quest** – add a `_quest(...)` block with a list of waves (each wave lists enemy
  ids and counts), rewards, recommended level and the quest it unlocks.

## 10. Replacing the placeholder visuals

Every visual is drawn at runtime. `assets/placeholders/README.md` lists exactly which
script draws what and how to swap in a texture:

| Placeholder | File | Replace with |
| --- | --- | --- |
| Hero / enemy silhouettes | `scripts/units/unit.gd` | a `Sprite2D` per `body_shape` |
| Enemy HP / break bars | `scripts/units/unit.gd` | `TextureProgressBar` |
| Battlefield backdrop | `scripts/battle/battle_scene.gd` | `Sprite2D` / `ParallaxBackground` |
| Damage & healing numbers | `scripts/ui/floating_text.gd` | a themed `Label` |
| Projectiles | `scripts/ui/projectile.gd` | `Sprite2D` + particles |
| Panels / buttons / bars | `scripts/ui/ui_style.gd` | a `Theme` resource |
| Item icons | `EquipmentDef.icon_color` | a `texture` export |

The combat rules never read visual state, so replacing art cannot change balance.

## 11. Tests

`tests/test_runner.tscn` runs four suites — **261 checks, all passing**:

| Suite | Checks | Covers |
| --- | --- | --- |
| `tests/test_combat.gd` | 117 | damage formula & mitigation, element table, crits, shields absorbing before HP, arts gauge spending and refusal, cooldown enforcement (rapid clicks cannot bypass it), status application/expiration/stat restoration, break start/end/reset, targeting and retargeting, dead units cannot act or be targeted, wave difficulty scaling, every synthesised sound contains real audio and rapid sounds are throttled |
| `tests/test_progression.gd` | 82 | XP curve, stat growth, level-up, currency, item drops, equipment ownership (a copy cannot be equipped twice), slot/category compatibility, party slot rules (no duplicates, max 4), reward duplication guard, save round-trip (including the volume setting), corrupt-save recovery, quest unlock validation |
| `tests/test_battle_flow.gd` | 25 | a full quest is played to victory by an auto-pilot (each quest is fought by a party at its recommended level), wave transitions leave no orphans, boss phase change happens exactly once, break triggers, ability wind-ups are telegraphed, pause freezes timers and HP, retry resets battle state, rewards are granted exactly once |
| `tests/test_ui.gd` | 37 | every screen instantiates, builds its widgets, covers the viewport and has clickable buttons; the controls overlay covers the whole viewport |

Run them with:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn
```

`tools/screenshot_tour.gd` (dev-only) renders every screen to `user://screenshots/`
and was used to verify the layout at **1280×720** and **1920×1080**.

## 12. Known limitations

* Prototype scope: **no gacha, no monetisation, no multiplayer, no accounts, no
  crafting, no large campaign.** Three quests and six heroes is the whole content set.
* Visuals are deliberately abstract placeholders (coloured shapes, labels, bars).
* Enemy AI is intentionally simple (interval + cooldown based, no advanced positioning).
* Sound effects are synthesised at runtime; there is **no music** and the sound design
  is placeholder-level.
* Balance is tuned for a level-1 party and has not been play-tested by humans at length;
  the numbers live in `tools/build_content.gd` and `scripts/core/balance_config.gd` and
  are cheap to adjust.
* The battle HUD is designed for a 16:9 landscape window; extreme aspect ratios will
  letterbox rather than re-flow.
* `U` on the quest board unlocks every quest — this is a prototype testing aid, not a
  progression feature.

## 13. Credits

Original work: all names, layouts, code and placeholder art in this repository were
written for this prototype. No third-party art, audio, fonts or code was copied in.
