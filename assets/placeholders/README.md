# Placeholder assets

The game ships **without any imported art**.  Every visual is drawn at runtime
with Godot's drawing API, so the project runs on a clean checkout with no
asset pipeline.

## Where the placeholders live

| What | Where | How to replace it |
| --- | --- | --- |
| Hero / enemy silhouettes | `scripts/units/unit.gd` (`_draw()` and the `_draw_*` helpers) | Replace the `Unit` node with a `Sprite2D` / `AnimatedSprite2D` and load a texture per `body_shape` id.  The `UnitDef.body_color`, `body_size` and `body_shape` fields then become sprite metadata. |
| HP / break bars above enemies | `scripts/units/unit.gd` (`_draw()`) | Use a `TextureProgressBar` or a `NinePatchRect` in a child node. |
| Battle background | `scripts/battle/battle_scene.gd` (`_draw()`) | Replace with a `Sprite2D` / `ParallaxBackground` using `res://assets/placeholders/`. |
| Damage numbers, ability names | `scripts/ui/floating_text.gd` | Swap the `draw_string()` call for a `Label` with a themed font. |
| Projectiles | `scripts/ui/projectile.gd` | Replace the drawn circle with a `Sprite2D` and a `GPUParticles2D` trail. |
| Buttons, panels, bars | `scripts/ui/ui_style.gd` | Build a `Theme` resource instead of the code based `StyleBoxFlat` helpers. |
| Item icons | `EquipmentDef.icon_color` | Add a `texture: Texture2D` export to `EquipmentDef` and draw it instead of the colour chip. |

## Adding real art later

1. Drop the files into `assets/placeholders/` (or `assets/art/`).
2. Add a `texture` export to the matching definition resource
   (`CharacterDef`, `EnemyDef`, `EquipmentDef`).
3. Use the texture in the view script instead of the drawn placeholder.

Nothing in the combat code depends on how a unit looks: the rules only read
`UnitDef` and `UnitState`.
