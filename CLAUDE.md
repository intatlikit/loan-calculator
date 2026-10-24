# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Thai-language mortgage amortization calculator (ตารางผ่อนบ้าน). The whole app is a single static file, `index.html`, with inline CSS and vanilla JS. There is no build step, package manager, linter, or test suite. The only external dependency is Google Fonts (Sarabun, IBM Plex Mono).

## Running

Open `index.html` directly in a browser, or serve the folder statically (e.g. `npx serve .` or `python -m http.server`). Changes take effect on reload.

## Architecture (inside `index.html`'s `<script>`)

**Calculation flow:** every input event calls `calculate()`, which rebuilds the whole schedule from scratch and calls `renderTable()`, which replaces `tbody.innerHTML` and re-attaches all row listeners. There is no incremental update, so any state that must survive a recalculation has to live in the module-level variables, not in the DOM.

- Interest is monthly: `balance * (annualRate / 100 / 12)`. The loop runs until the balance is ≤ 0.005 or 1200 rows (`MAX`). The last payment is capped at `balance + interest`.
- `calculate()` refuses to build a table if the default payment is ≤ the first month's interest. It shows a warning state instead.

**Per-row overrides:** `customPayments` and `customRates` are objects keyed by the **0-based row index** (`idx`), not the displayed period number `n = idx + 1`. Inline inputs in the table write to these maps on blur/Enter. Entering the default value (or an empty value) deletes the override. The ✕ reset buttons also delete it. Overrides are deliberately kept when the main inputs or the start date change.

**Profiles (localStorage):** all profiles are stored as one JSON object under the key `mortgage_profiles_v1`, as `{ [id]: profile }`. A profile holds the raw formatted input strings (`balance`, `payment`, `rate`), `startMonth`/`startYear`, copies of `customPayments`/`customRates`, and `savedAt`.
- `activeProfileId` tracks the current profile.
- The 💾 button (or Enter in the name field) saves immediately.
- Autosave also runs `saveProfile({ silent: true })` 3s after the last edit (`scheduleAutosave()`). Any new user-edit handler must call `scheduleAutosave()`.
- `flushAutosave()` saves pending edits right away. It runs before switching, creating, or deleting a profile, and when the page is hidden or closed. If you add another action that replaces the form, call `flushAutosave()` first.
- Inline table cells commit only on blur or Enter, and only when the value changed. The 3s countdown starts from that commit, not from each keystroke.
- JSON turns the override map keys into strings, so `applyProfile()` converts them back to numbers. Keep doing this if you touch that code.
- On load, the profile with the latest `savedAt` is applied. Tabs are sorted by `savedAt` ascending.
- If you change the profile shape in a way that isn't backward compatible, bump the `LS_KEY` version.

**Supabase sync (optional, no login):** the app syncs only when `window.APP_CONFIG` provides `SUPABASE_URL` and `SUPABASE_ANON_KEY`. If they're missing, the sync bar stays hidden and the app runs local-only. supabase-js is loaded from jsdelivr.
- `APP_CONFIG` is defined in `config.js`. Locally, `config.js` is gitignored; copy `config.example.js` to create it. On deploy, `.github/workflows/deploy.yml` generates `config.js` from the repo secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SYNC_KEY`, then publishes `index.html` and `config.js` to GitHub Pages. Never hard-code these values in `index.html`.
- The schema is in `supabase/schema.sql`. The `mortgage_store` table has one row per sync key, and its `data` jsonb column holds the same object that is stored under `LS_KEY`.
- The table has RLS enabled with no policies, so the anon role can't read or write it directly. All access goes through the `security definer` RPC functions `get_mortgage_store(p_key)` and `set_mortgage_store(p_key, p_data)`. Never add a table policy for anon: the anon key is public, so anyone could then read or overwrite every row.
- The sync key is the only secret.
  - If `APP_CONFIG.SYNC_KEY` is set, every device uses that one key and so shares one row. Anyone who can open the deployed site can then read and edit that row.
  - If it's not set, each browser generates a random 32-hex key once and stores it in `LS_SYNC_KEY`, so each browser has its own row.
  - There is no UI to view or change the key.
- `pullRemote()` also runs when the tab becomes visible again, unless an autosave or push is pending. That's how edits made on other devices show up. Sync is last-write-wins on the whole object; there is no per-profile merge.
- Supabase is the source of truth and localStorage is a cache. `saveAllProfiles()` writes to localStorage and then calls `pushRemote()`. `pushRemote()` queues uploads in order, and each upload sends the latest localStorage copy.
- `LS_DIRTY_KEY` holds the sync key whose local changes haven't been uploaded yet.
- On load, `pullRemote()` replaces the local data with the cloud row. It uploads the local data instead in two cases: no row exists for that key yet, or an earlier upload with that key failed (the key is still in `LS_DIRTY_KEY`).

**Dates and locale:** months are stored 0-based (JS convention). Years are stored as Gregorian years and shown in Buddhist Era (`year + 543`). The start-year `<select>` only contains the current year ±5. All UI text is in Thai.

**Number input handling:** inputs are `type="text"` and get comma-formatted as the user types. `parse()` strips the commas back out, `fmt()` formats output to 2 decimal places, and `fmtInput()` formats values put back into inputs. The format-while-typing logic is currently written out in full in both the main-input handler and `attachInlineInput()`, rather than calling `fmtInput()`.

## Styling

Colors are CSS custom properties on `:root` (dark theme only). Summary cards use the modifier classes `accent`, `gold`, `green`, `red` and `purple`. In the table, the `.custom` class marks an overridden cell and `.paid-off` marks the final row.
