# FTCS - Programming Lessons Learned (Base de Conocimiento Técnica)

<!--
    PURPOSE:
    This file is the project's LIVING TECHNICAL KNOWLEDGE BASE. It records two
    kinds of entries, both numbered sequentially and dated (newest at the BOTTOM):

    1. PROGRAMMING LESSONS - every non-obvious programming finding, root-cause
       analysis, engine quirk or debugging lesson discovered while developing
       FTCS (Arma 3 SQF today, Enforce Script / Arma 4 tomorrow).
    2. ARCHITECTURE / DESIGN NOTES - whenever a structural change to the software
       is made, or a mechanism crucial to understanding how FTCS works is added
       (e.g. the data structure lifecycle, the central registry/hash model, the
       order-propagation chain), an entry written as a DIRECT GUIDE FOR AN AI:
       oriented to automatic consumption - invariants that must not be broken,
       module contracts, what to read and in which order to understand the
       system, and how NOT to break it when programming on top of it.
       This is DISTINCT from and complementary to the human-oriented design
       documentation: that explains the WHAT and WHY for the programmer; these
       notes explain HOW IT WORKS and HOW NOT TO BREAK IT for the AI coding on it.

    RULES FOR THE AI (and the human programmer):
    - READ THIS FILE COMPLETELY before writing or debugging any code in this project.
    - Every entry must describe a REAL problem that actually occurred in this
      project, its verified root cause, and the fix that was proven to work.
    - Entries are numbered sequentially and dated (newest at the BOTTOM).
    - When a new lesson is learned during any task, ADD IT HERE as the next entry.
    - Do not delete entries; if a lesson becomes obsolete, mark it as such but
      keep the historical record.
    - Language: English (technical reference for AI consumption), per the
      project's Point 0 rules for all code/documentation meant for the engine.
-->

## Index

| # | Date | Type | Topic | Module / File |
|---|------|------|-------|---------------|
| 1 | 2026-11-13 | Lesson | `continue` keyword is NOT supported inside `forEach` loops (SQF) | `Functions/Targeting/fn_targetPersistentMarker.sqf` |
| 2 | 2026-11-13 | Arch/Design | Mission-folder linker: NTFS Junctions + hardlinks, one versioned repo for all terrains | `LinkMission.bat`, `tools/LinkMission.ps1` |

---

## Lesson 1 — `continue` inside `forEach` breaks SQF compilation with "Error in expression / 0 elements provided, 3 expected"

**Date:** 2026-11-13
**Module:** `Functions/Targeting/fn_targetPersistentMarker.sqf` (Draw3D mission event handler)
**Symptom:**

- Recurring RPT error `Error in expression <...> / 0 elements provided, 3 expected`, always pointing at or near the `drawIcon3D` call that draws the squad-name caption (reported around "line 109" / "l109" in the RPT).
- The error **moved to different line numbers** (66 → 73 → 109) as guards and code were added/removed, which made it look like a data problem.
- The crash happened every frame, deterministically, ONLY when the Draw3D handler was re-spawned (e.g. after `targetClearAllSquads` wiped targets and a new capture re-created the handler). Moving/re-marking a target while the old handler was still alive worked fine.

**Wrong hypotheses we chased (and why they failed):**

1. "The marker position array is nil/partially cleared mid-frame" → added `typeName`/SCALAR guards everywhere. Did NOT fix it: the failure happens at COMPILE time of the handler closure, before any guard can run.
2. "The engine is running an old version of the file" → false; the RPT error line moved with our edits, proving the new file was loaded.
3. "`drawIcon3D` receives a 0-element array" → the array literal was correct; the real problem was upstream in the same expression.

**Verified root cause (researched against the BI wiki, [continue - BI Community Wiki](https://community.bistudio.com/wiki/continue)):**

- The SQF keyword `continue` (introduced in Arma 3 v1.92) is **only supported in `while do`, `for do` and `do..while` loops**. It is **NOT supported inside `forEach` loops** — the [forEach](https://community.bistudio.com/wiki/forEach) wiki page documents no `continue` support either.
- When the SQF parser finds `continue` in a `forEach` body, it treats it as an orphan binary operator and **consumes the following expression** (in our case the `drawIcon3D [...]` array literal, whose parameters come in 3 groups — hence "3 expected") as its operands. The closure **fails to compile**, and because a `Draw3D` handler is recompiled/evaluated every frame, the error repeats every frame.
- This explains why the "fix" never worked regardless of runtime guards: **the guards were in code that never got to run**, because the enclosing closure could not even be compiled.

**The fix that worked (applied and verified in-game):**

- Rewrote the `forEach` body of the Draw3D handler as a cascade of **nested positive `if/then` blocks with NO `continue` at all**:

  ```sqf
  {
      // ...
      if (count _tgt >= 8
          && { typeName (_tgt select 1) == "STRING" }
          && { !((_tgt select 1) in ["any", "", "OBJECT"]) }) then {
          // ... field-level validations ...
          if (_impactOk && { _labelOk } && { _distanceOk }) then {
              // ... markerPos computation + final gate ...
              if (typeName _markerPos == "ARRAY"
                  && { count _markerPos == 3 }
                  && { typeName (_markerPos select 0) == "SCALAR" /* etc. */ }) then {
                  drawIcon3D [...];
              } else {
                  diag_log "REFUSED ...";  // instead of 'continue'
              };
          };
      };
  } forEach FTCS_Groups_Registry_Table;
  ```

- Rule of thumb: **inside `forEach`, use nested `if/then` (or an `if (...) then { ... } else { ... };` structure) to skip iterations — never `continue`.** `continue` is legal only in `while do` / `for do` / `do..while` loops (existing valid uses in this project: `fn_formationsGroupFollowTrail.sqf`, `fn_marchStuckWatchdog.sqf` — both `while` loops).

**Debugging meta-lesson:** when an SQF error keeps appearing at "the line of a big array literal" and moves around as unrelated code is edited, suspect a **parse/compile-level problem in the same expression or an earlier statement in the same closure** (orphan keyword, unbalanced brackets, binary operator misparse) — not a runtime data problem. Adding more runtime guards cannot fix a closure that never compiles.

---

## Lesson 2 — Mission-folder linker (`tools/LinkMission.ps1` + `LinkMission.bat`): NTFS Junctions + hardlinks keep ONE versioned codebase for every terrain

**Date:** 2026-11-13
**Type:** Architecture / Design Note (direct guide for an AI)
**Module:** `LinkMission.bat` (repo root) → `tools/LinkMission.ps1`

**Problem it solves:**

- Arma 3 identifies each mission by `<MissionName>.<Terrain>` folder name, so testing the same FTCS codebase on a new terrain requires a NEW mission folder — and a NEW, terrain-specific `mission.sqm` that Eden refuses to share.
- Copying `Functions/`, `Doctrines/`, `init.sqf`, etc. into every mission folder would fork the codebase and pollute the GitHub history.

**Architecture ("repo without mission.sqm"):**

- The repo lives in ONE mission folder (currently `FTCS_Dev_Mission.Colleville`) and is the GitHub-versioned source of truth.
- `LinkMission.bat` (repo root) runs `tools/LinkMission.ps1`, which asks for the destination mission folder name and that mission's Eden-generated `mission.sqm`, then:
  1. Creates an NTFS **Junction** (no admin rights needed, unlike symbolic links) inside the destination mission folder for every SHARED item: `Functions`, `Doctrines`, `tools`, and hardlinks for shared files `description.ext`, `init.sqf`, `LinkMission.bat`. Editing code in EITHER folder edits the SAME files.
  2. Copies as REAL local files the per-mission exclusives: `mission.sqm` (each terrain keeps its own world).
- Existing destinations are handled safely: previous junctions are repositioned with `.Delete()` on the reparse point only (NEVER `Remove-Item -Recurse` through a junction — on PowerShell 5.1 it can traverse INTO the repo and delete the real codebase); real files/folders are only replaced after explicit user confirmation.

**Invariants an AI must NOT break:**

- NEVER delete a junction with recursive filesystem tools; delete only the link itself.
- `mission.sqm` must NEVER be linked/hardlinked into the repo — it stays a per-mission local copy (a generic mission.sqm breaks Eden loading on other terrains).
- Shared-item lists live in the `$SharedItems` / `$LocalFiles` arrays at the top of `LinkMission.ps1`; any new top-level shared folder or file of the project must be added there, or new missions will silently miss it.
- Workflow for a new terrain: 1) create+save the empty mission in Eden (generates its mission.sqm), 2) run `LinkMission.bat` from the repo, pointing at that mission.sqm.
