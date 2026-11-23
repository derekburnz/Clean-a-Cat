# Decisions

What was decided and why, newest at the bottom. Append, never rewrite: when a decision changes, add a new line that says what it replaces. On a merge conflict keep both sides, main's first.

Format: `YYYY-MM-DD: <decision>. Why: <reason>. (who decided)`

## Decided
2026-11-23: Art style is Bubble Pastel colours (cream #FFF6EC, mint #A8E6CF, bubblegum #FFB3C7, sky #8FD3FE, mud #5A4632) on the blocky chibi shapes of Derek's asset library, written up in `docs/art/style-guide.md`. Why: the blocky cat body is already approved by Derek and proven on phones, flat colours cost no texture memory, and dark mud stands out on every coat, which is the whole first 15 seconds. Derek can swap to Cozy Storybook or Bright Toy. (Model-Agent, recommended pick while Derek's answer is pending)
2026-11-23: Models are built by Python generators in `assets/clean-a-cat/blender/`, ported from Derek's asset library (derekburnz/Roblox-Asset-Library, models/blender-generators), and ship as Part-built `.model.json` files in `assets/clean-a-cat/rbx/`. Why: a style change is a code edit and a rebuild, and Part models load in a group-owned game with no mesh uploads. Only the cat body code is shared with Cat Cafe; every Clean a Cat cat has its own name and coat. (Model-Agent)

## Proposed
Notes from a role that needs a change outside its own folders, or a design call waiting on the owner.
