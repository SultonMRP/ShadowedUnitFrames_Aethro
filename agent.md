# Shadowed Unit Frames agent notes (Aethro)

WotLK 3.3 (`Interface: 30300`) unit frames by Shadowed, packaged `v3.2.12-5-g3fb7edd`, customized for Aethro Reforged. This folder is the **main addon**. One sibling lives next to it:

| Folder | Role |
|---|---|
| `ShadowedUnitFrames` | Engine: units, bars, tags, layout. Saved var: `ShadowedUFDB` |
| `ShadowedUF_Options` | Load-on-demand `/suf` dialog. Depends on ShadowedUnitFrames |

Slash: `/suf`, `/shadowuf`, `/shadoweduf`, `/shadowedunitframes` → `LoadAddOn("ShadowedUF_Options")` → `ShadowUF.Config:Open()`.

Do not treat this as retail/Cata SUF. APIs are 3.3: `GetNumRaidMembers`, `UnitAura` 8-return, `GetChecked() == 1`, AceDB-3.0 + AceConfig-3.0 in Options.

Related tooltip work (same paragon protocol): `TipTac\agent.md`.

---

## What we changed (session work)

Original package had **no** paragon number and **no** item level. User asked for **paragon only**. Item level was not added.

### 1. `[paragon]` / `[paragon()]` tags

Lives in **`modules\paragon.lua`**, not `tags.lua`. Tag tables are injected at runtime only if AethroParagon is loaded.

- `[paragon]` returns the **number only**.
- `[paragon()]` returns the number in parentheses, e.g. `(12)`. Registered as its own tag name so SUF looks it up before treating `()` as an empty suffix.
- Only shown for **players** (`UnitIsPlayer`). NPCs, mobs, and pets stay blank. Hook 6 replies are ignored unless the current target is a player.
- Category: **Classifications** (next to `[level]`).
- Events: custom `PARAGON` + `PLAYER_TARGET_CHANGED`.
- Uses `unitOwner` so vehicle swap still reads the player.

Copy-pattern for async tag updates: `modules\incheal.lua` (`HEALCOMM` / `EnableTag` / `UpdateTags`).

Not baked into `defaultlayout.lua`. Existing profiles keep their text until the user adds the tag in `/suf` → unit → **Text/Tags**.

### 2. AethroParagon gate

Same rule as TipTac after this session: if AethroParagon is missing or disabled, do not show the option and do not touch its APIs.

| Check | Where |
|---|---|
| `## OptionalDeps: …, AethroParagon` | `ShadowedUnitFrames.toc` (loads AethroParagon first when present) |
| `IsAddOnLoaded("AethroParagon")` | `modules\paragon.lua` before register / hooks / `SendClientRequest` |
| Same `IsAddOnLoaded` hide | `ShadowedUF_Options\config.lua` tag wizard + Advanced tag list |

If the addon is absent:

- `[paragon]` is **not** in `Tags.defaultTags`, so it does not appear in Text/Tags or Add tags.
- No `hooksecurefunc`, no hook 1 / hook 6.
- Leftover `[paragon]` in a saved text string shows `[paragon-error]` (unknown tag), not a Lua error.

### 3. TipTac got the same gate

Not in this folder. Done in the same session so both addons behave alike:

| File | Change |
|---|---|
| `TipTac\TipTac.toc` | `OptionalDeps: AethroParagon` |
| `TipTacTalents\TipTacTalents.toc` | `OptionalDeps: TipTac, AethroParagon` |
| `TipTacTalents\core.lua` | `IsAethroParagonLoaded()`; no tip line / hooks unless loaded |
| `TipTacOptions\Options.lua` | **Show Paragon Level** appended on Special only if loaded |

---

## How to show it

`/suf` → unit (player, target, …) → **Text/Tags** → enable **Paragon** / **Paragon (parentheses)**, or type the tag.

```
[paragon]                    → 12
[paragon()]                  → (12)
[( )paragon]                 →  12
[level][paragon()] [perpp]   → 80(12) 50%
```

`[( )paragon]` is still “space then number” via SUF prefix syntax. Use `[paragon()]` when you want built-in parentheses.

---

## AethroParagon protocol

`D:\Warcrafts\Aethro\Interface\AddOns\AethroParagon` talks to the server over CMH. There is no `GetParagonLevel(unit)` API.

| Hook | Request | What it returns |
|---|---|---|
| 1 | `SendClientRequest("ParagonAnniversary", 1)` | **Your** paragon level |
| 6 | `SendClientRequest("ParagonAnniversary", 6)` | **Current target only**. No unit/name/GUID arg. Server uses your target. |

Portrait FontStrings: `ParagonCharacterLevel.Text` (you), `ParagonTargetLevel.Text` (target, only if `lastTargetGUID` matches and alpha > 0).

We:

- Hook `UIParagon_OnClientReceiveLevel` and `UIParagon_OnReceiveTargetLevel`.
- Cache by GUID and name.
- Self: hook 1 once if unknown. Target: hook 6 only while the unit **is** `target`, once per GUID.
- Focus / party / raid: cache if previously targeted. Never request hook 6 for them.

**Hard limit:** a player you have never targeted cannot get a number. Do not call hook 6 unless the frame unit **is** the current target, or you will paint the target's paragon on the wrong person.

AethroParagon notes: `AethroParagon\agent.md`.

---

## Options layout (current)

`ShadowedUF_Options\config.lua` — one real file, AceConfig dialog `835×525`.

1. **General** — media, colors, global text slots, layouts, profiles
2. **Enable units**
3. **Unit configuration** — per-unit tabs: General / Frame / Bars / Widget size / Auras / Indicators / **Text/Tags**
4. **Aura filters**
5. **Hide Blizzard**
6. **Zone configuration**
7. **Add tags** — hidden unless **Advanced** is on

Tag pickers walk `ShadowUF.Tags.defaultTags`. A built-in tag appears automatically if those tables are filled (`defaultTags`, `defaultEvents`, `defaultCategories`, `defaultHelp`, `defaultNames`). No new Options page is required for `[paragon]`.

`OnConfigurationLoad` fires after the options table is built if a future module needs its own page.

---

## Key files

| Path | Why it matters |
|---|---|
| `ShadowedUnitFrames\modules\paragon.lua` | Cache, hooks, `[paragon]` registration, AethroParagon gate |
| `ShadowedUnitFrames\modules\tags.lua` | Tag engine. Do **not** put paragon tables here (would show with AethroParagon off) |
| `ShadowedUnitFrames\modules\incheal.lua` | Custom-event tag pattern (`EnableTag` / `DisableTag` / refresh) |
| `ShadowedUnitFrames\modules\layout.lua` | `SetupText` attaches `[tag]` strings to FontStrings |
| `ShadowedUnitFrames\modules\units.lua` | Events, FullUpdate, `unit` vs `unitOwner`, fake-unit poll |
| `ShadowedUnitFrames\modules\defaultlayout.lua` | Stock `[tag]` strings. Paragon not added |
| `ShadowedUnitFrames\ShadowedUnitFrames.toc` | Loads `paragon.lua` after `tags.lua`. OptionalDep AethroParagon |
| `ShadowedUnitFrames\localization\enUS.lua` | `L["Paragon"]` + help. Other locales inherit via metatable |
| `ShadowedUF_Options\config.lua` | Hides `paragon` in the picker if AethroParagon is not loaded |
| `TipTacTalents\core.lua` | Same protocol on tooltips |
| `AethroParagon\Paragon\Paragon_Network.lua` | Hook 1 / hook 6 callbacks |
| `AethroParagon\Paragon\Paragon_TargetLevel.lua` | Target change → request 6 |

---

## Working rules

- Match existing Shadowed style: tabs, `if( x ) then`, short `--` notes.
- Ace3 is already here (AceDB + Options AceConfig). Do not add a new SavedVariables table for paragon.
- Do **not** `RegisterModule` paragon as a visible unit widget. It is tag-only (`ShadowUF.Paragon` + `Tags.customEvents["PARAGON"]`). A named module would show up in zone/visibility toggles.
- Tag function must stay `(unit, unitOwner)` and return a string or `nil`.
- Keep `[paragon]` a bare number. `[paragon()]` is the paren variant. Other wrappers stay the user's text string.
- Never show or cache a paragon number unless `UnitIsPlayer` is true. Do not write hook 6 onto the current target if that target is an NPC.
- Register tag tables only from `paragon.lua` after `IsAddOnLoaded("AethroParagon")`. Putting them in `tags.lua` makes the option appear without the addon.
- If adding another Aethro server number as a tag, hook the existing receive function and cache by GUID. Do not invent a unit-targeted request unless the server grows a new hook.
- Do not add player item level unless asked. That is inspect + `INSPECT_TALENT_READY` (see TipTacTalents). One inspect at a time globally; do not inspect every raid frame.
- Fake units (`targettarget`, `focustarget`, …) have no real events (0.5s poll). Cache only. Do not inspect or call hook 6 from them.

---

## Known limits / leftovers

- Paragon: self + current target + cache of past targets. No stranger on party/focus/raid until you have targeted them.
- Hook 6 has no unit token. Same hard limit as TipTac.
- Tag is not in stock layout text. User must add `[paragon]` per unit.
- Leftover `[paragon]` in a profile with AethroParagon disabled shows `[paragon-error]`.
- Help/name strings are English-only (`enUS`). Other locales fall back.
- No `agent.md` existed in this folder before this session.
