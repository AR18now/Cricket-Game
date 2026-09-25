# Visual & audio style guide (v0.1)

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| Emerald | `#085C45` | Batting kit, buttons, panels (integrated accents, not flags) |
| Emerald deep | `#052B21` | Panel backgrounds, splash |
| Warm sand | `#F2DEB3` / field `#C49A69` | Secondary text, packed-earth field |
| Off-white | `#FAF7ED` | Crease markings, primary text, trousers |
| Terracotta | `#D16945` | Brick, awnings, primary PLAY action, cones |
| Floodlight gold | `#FCC954` | Highlights, focus rings, boundary banners, bunting |
| Ink | `#141210` | Outlines (all characters and the ball are outlined) |
| Ball | `#FFF285` + red tape `#D91F1F` | Must contrast with every background; never recoloured |

Fielding side uses a contrasting indigo (`#3366BF`); batting kit is player-selectable from
five swatches.

## Silhouettes & proportions

- Oblique fixed side view; 1 m = 48 px at zoom 1; lateral depth foreshortened to 0.24.
- Cricketers ≈ 1.75 m, thick rounded limbs, dark outline pass then fills (far limbs 20 %
  darker). Batters wear helmet, pads and gloves; keeper has gold gauntlets; umpire white coat,
  dark trousers, hat.
- Stumps are fanned slightly in screen space so all three read at phone size.

## Type

Lato (OFL): Black for scores/titles, Bold for UI, Regular for explanations. Minimum 15 px at
the 1280×720 reference; primary numbers 40 px+. Text is never the only carrier of meaning:
over chips use text symbols (`W`, `4`, `6`, `-`) plus shape/fill.

## UI shapes

Rounded panels (radius 14–22), 2 px gold-tinted borders, translucent deep-emerald fills over
the living ground. Buttons ≥ 58 px tall (PLAY 92 px); icon buttons are vector-drawn (no font
glyph dependency).

## Motion

- Delivery: fixed camera; no shake, no flashes.
- After contact: exponential follow (rate 3.2/s), zoom 0.36–0.9, ball always kept inside a
  12 % margin. Reduced motion: static overview, no trail, no contact spark, kites stop.
- Effects are brief (≤ 1.2 s) and never cover the ball: bounce dust, contact spark, rope ring.

## Audio palette

Tape-ball crack (4 variants + edge), dull pitch thud (3 variants), wooden stump clatter,
glove slap, bat whoosh, soft run-up steps; courtyard ambience (evening birds, distant hum,
tea-cup clinks); crowd bed + cheers/groan/anticipation; dhol-inspired original percussion
stings and a short drone-and-percussion music loop. Buses: Music, SFX (Ambience, Crowd,
Impacts, UI), Voice; master limiter at −0.5 dB.
