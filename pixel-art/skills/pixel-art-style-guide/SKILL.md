---
name: pixel-art-style-guide
description: Writes and maintains the pixel-art style guide of a game — the document that fixes resolution, tile and sprite sizes, perspective, palette, light direction, outlines, shading, animation timing and file conventions, so that art made at different times still looks like one game. Use when starting the art of a game, when defining or changing its visual style, when sprites from different sources or sessions do not match, or before asking anyone to draw. Turns each decision into a rule that can be checked, and says which existing art a change invalidates.
---

# Write a pixel-art style guide

Pixel art drifts. Each sprite looks fine alone, and together they look like three different games: one has black outlines, one is lit from the right, one uses a blue nobody else uses. A style guide prevents that by making the decisions once and writing them where everyone who draws will read them.

A rule earns its place when it can be checked: by a script, or by looking at a sprite for a few seconds. "Characters should feel friendly" cannot be checked. "Characters are 16 pixels wide and outlined in the darkest colour of their own ramp" can.

## Procedure

1. **Look at what exists.** If the game has art, the guide describes it before it prescribes anything. Measure the sprites and tiles, look at them enlarged, and note what they agree on — size, outline, light, palette — and where they disagree. The disagreements are the decisions that have to be made.

2. **Find out what cannot be derived.** The mood, the references, the target resolution and the scope of the game come from whoever owns it. Ask for what is missing. Do not fill a gap with a guess presented as a decision.

3. **Decide in dependency order.** Each of these constrains the next:
   1. The base resolution, and the tile size.
   2. The perspective: side view, top-down, three-quarter, isometric.
   3. The size of a character relative to a tile.
   4. The palette.
   5. Light, outline and shading.
   6. Animation.
   7. File conventions.

4. **Write it from the template** in [assets/style-guide-template.md](assets/style-guide-template.md). Fill every section. A section the game does not need is marked "not used", not deleted: the next reader then knows it was considered.

5. **State each rule so that it can be checked,** and give the reason in a clause. The reason is what lets someone handle a case the rule did not foresee.

6. **Make a reference sheet.** One character, one tile and one object that follow every rule, kept beside the guide. New art is compared with the sheet, not with a memory of it.

7. **Put the guide where the art is,** in the repository, as Markdown. Follow the project's own layout for documents. If it has none, `docs/art-style.md` is a reasonable place.

## What the guide has to decide

**Resolution and grid**

- The base resolution of the game, in art pixels.
- The tile size, and the sizes sprites come in: characters, items, icons.
- One pixel size everywhere. All art is drawn and exported at 1×, and nothing in the game is scaled by a fraction. Mixed pixel sizes are the most visible break in cohesion there is.

**Perspective**

- The projection, and with it which faces of an object are visible and where the ground line is.
- Where shadows on the ground go, if there are any.

**Palette**

- The palette file, the number of colours, and the ramps with the material each one serves.
- Roles: the outline colour or colours, the shared shadow colour, the accents reserved for what the player has to notice.
- What is not allowed: colours outside the file, partial transparency, gradients.

**Light and shading**

- One light direction for all art. Top left is the usual choice.
- How many shades a material gets, and whether a highlight is a separate step.
- Whether dithering is allowed, and where. The same for anti-aliasing inside a sprite. Never on the outer edge.

**Outline**

- None, one colour for everything, or a darker shade of whatever is being outlined.
- Where it is one pixel thick, where it breaks, and whether it is lightened on the side facing the light.
- Whether characters are outlined and the environment is not. This is a common way to make what moves stand out from what does not.

**Shapes and readability**

- Proportions: how many pixels tall a character is, and how large its head is.
- The level of detail that goes with each sprite size.
- How the foreground is kept apart from the background: contrast, saturation, outline.

**Animation**

- The frames each action gets, and how long a frame lasts.
- Where the pivot is — bottom centre for anything that stands on the ground — and that it does not move between frames.
- The sheet layout: frame size, direction, padding.

**Tiles**

- Which tiles have to repeat seamlessly, how many variants a surface gets, and how transitions between surfaces are laid out.

**Interface**

- The fonts and the sizes they are used at, in whole multiples of their design size.
- Icon sizes, and how panels and buttons are drawn.

**Files**

- Where source files and exported PNGs live, and how they are named.
- Which is the source of truth when both exist.

## Changing the guide

A change to the guide is a change to every sprite already drawn under it. Before changing a rule:

- List the existing art that the new rule makes wrong.
- Say whether that art is to be redrawn, and by when, or left as a known exception.
- Give the change a date in the guide's change log, with its reason.

A rule the art has stopped following is worse than no rule. Either the art changes or the rule does.

## Common failures

- **A mood board instead of rules.** Adjectives and reference images that leave every decision to whoever draws next.
- **Rules without numbers.** "Small outline" and "limited palette" where "one pixel" and "24 colours, listed in `palette.hex`" were available.
- **A guide nobody can find.** Kept in a chat, a design tool or someone's head rather than next to the art.
- **Decisions made by accident.** The first sprite drawn becomes the style because nobody wrote down a choice. Describe it, decide whether to keep it, and write the answer.
