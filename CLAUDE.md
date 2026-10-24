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
- `activeProfileId` tracks the current profile. Saving is manual (the 💾 button or Enter in the name field). Edits are **not** auto-saved.
- JSON turns the override map keys into strings, so `applyProfile()` converts them back to numbers. Keep doing this if you touch that code.
- On load, the profile with the latest `savedAt` is applied. Tabs are sorted by `savedAt` ascending.
- If you change the profile shape in a way that isn't backward compatible, bump the `LS_KEY` version.

**Dates and locale:** months are stored 0-based (JS convention). Years are stored as Gregorian years and shown in Buddhist Era (`year + 543`). The start-year `<select>` only contains the current year ±5. All UI text is in Thai.

**Number input handling:** inputs are `type="text"` and get comma-formatted as the user types. `parse()` strips the commas back out, `fmt()` formats output to 2 decimal places, and `fmtInput()` formats values put back into inputs. The format-while-typing logic is currently written out in full in both the main-input handler and `attachInlineInput()`, rather than calling `fmtInput()`.

## Styling

Colors are CSS custom properties on `:root` (dark theme only). Summary cards use the modifier classes `accent`, `gold`, `green`, `red` and `purple`. In the table, the `.custom` class marks an overridden cell and `.paid-off` marks the final row.
