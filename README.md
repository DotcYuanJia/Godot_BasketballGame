# BA Greybox Prototype


Controls:
- Move: WASD or arrow keys
- Sprint: Shift
- Shoot / pickup: J
- Change dribble hand: K
- Reset home possession: Space

Current match logic:
- One playable home character, one simulated away possession.
- 3-minute single quarter.
- 24-second shot clock.
- 2/3 point scoring based on release distance from the rim.
- Made shots, shot-clock violations, and out-of-bounds enter dead-ball/check-ball flow.
- Away possessions are skipped after a short delay until AI is implemented.

