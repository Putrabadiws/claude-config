# Burger Bangor (Bangor Group Indonesia) — business + engineering context

> **Source of this context:** `~/.claude/hooks/bangor-context.md`, injected at SessionStart by `~/.claude/hooks/bangor-context.sh` (fires when the current git repo is under the `Bangor-Group-Indonesia` GitHub org). Edit the `.md` to change the content; edit the `.sh` to change when it fires.
>
> **Placeholders marked `<<CONFIRM: ...>>` need user input** — do not invent answers; ask before relying on them.

## Org

- GitHub org: https://github.com/Bangor-Group-Indonesia/
- Active repos: `bangor-admin` (franchise ops UI — this repo), `menu-engineering` (menu/pricing — separate concern, do **not** model menu data in bangor-admin), `bangor-claude-config` (shared Claude config).

## Business — what Burger Bangor is

- Indonesian QSR chain — burgers, halal, 100% Australian beef.
- Founded **8 Aug 2019** in West Jakarta. Current owners: **Denny Sumargo** (ex-national basketball player, public figure) + **Hendi K**. Original co-founder Anli Maleaki Butar exited in 2021 — name may appear in legacy contracts/docs.
- **~700+ outlets across Indonesia as of 2025** (figure is press-cited and drifts; treat as a magnitude, not exact). Coverage: Jabodetabek, Java, Bali, Sulawesi (Makassar), expanding outside Java.
- Largest local burger network in Indonesia per MURI; largest local drive-thru network.
- Franchise-led model. Some outlets are "Semi Flagship" / "Bangor 2.0" formats.

## Menu tiers (lives in `menu-engineering`, not here — included for shared vocab only)

By patty count / price, **smallest → largest**:

`Jelata` (1 patty, ~Rp16k) → `Juragan` (1 larger patty, ~Rp23k) → `Ningrat` (2 patties) → `Sultan` (3 patties + 3 cheese, ~Rp45k)

> ⚠️ Earlier versions of this doc had `Sultan → Ningrat` reversed. Sultan is the **top** tier.

## Engineering implications (load-bearing for code decisions)

- **Region scoping is non-negotiable.** Every list/mutation must filter by region via `scopedWhere()`. Cross-region data leak = breach of franchise tenancy. See project CLAUDE.md "RBAC + scoping".
- **Scale signals.** ~700+ outlets, growing. Default to paginated lists, clustered map markers, indexed FK lookups. Don't ship unbounded `SELECT *` to the UI.
- **Indonesia spans 3 timezones** — WIB (UTC+7, Jakarta/Java), WITA (UTC+8, Bali/Makassar), WIT (UTC+9, Papua). <<CONFIRM: is per-outlet `timezone` stored, or do we assume Asia/Jakarta everywhere? Affects audit timestamps, contract expiry, scheduled jobs.>>
- **Currency: IDR**, no practical subunit. Display as `Rp 25.000` (Indonesian thousands separator = `.`). <<CONFIRM: is there a shared money formatter, or hand-rolled per page?>>
- **UI language.** <<CONFIRM: is the admin UI English-only, Bahasa Indonesia, or bilingual? Public brand is BI; internal admin tooling often stays English.>>

## Domain vocabulary (verified against `packages/shared/src/enums.ts`)

- **Roles** (`ROLE_NAMES`): `admin` (global), `regional_manager` (scoped to one `region_id`), `outlet_pic` (scoped to one `outlet_id`, can only `update_pic` on outlet), `viewer` (read-only). "PIC" = Indonesian biz term, Person-In-Charge.
  - <<CONFIRM: persona behind each role. Is `regional_manager` HQ staff overseeing regional franchisees, or the franchisee themselves? Is `outlet_pic` an HQ employee or franchise-side staff at the outlet?>>
- **Ownership types** (`OWNERSHIP_TYPES`): `mitra` (single-outlet franchisee), `master` (multi-outlet franchisee — distinct for commission reporting), `pusat` (HQ/corporate), `bbt` (separate Bangor sub-entity — distinct legal owner from `pusat`, operationally equivalent).
- **Outlet statuses** (`OUTLET_STATUSES`): `active`, `pending_opening` (opening date known), `to_be_announced` (committed but no date), `temporarily_closed`, `closed`.
- **Contract types** (`CONTRACT_TYPES`): `initial`, `renewal`, `amendment`.

## External surfaces (for context — integration scope below)

- **Delivery aggregators**: GoFood, GrabFood, ShopeeFood — all three run brand-takeover promos regularly. The brand lives on these platforms; whether *this admin* integrates with them is a separate question. <<CONFIRM: does `bangor-admin` pull sales/order data from any of these, or is it purely franchise-ops with no aggregator integration?>>
- **POS / sales data origin.** <<CONFIRM: where does per-outlet revenue (if tracked here) come from — manual entry, POS pull, aggregator pull, separate repo?>>
- **Payments**: QRIS is dominant in Indonesian retail. <<CONFIRM: any payment integration in scope for bangor-admin?>>

## Compliance / data

- **UU PDP** (Undang-Undang Pelindungan Data Pribadi — Indonesia's data protection law, in force) governs personal data on franchise owners, outlet PICs, and any staff records. <<CONFIRM: documented compliance stance / data-retention policy, or informal?>>
- Halal certification (BPJPH) is mandatory for F&B in Indonesia. <<CONFIRM: do we track per-outlet halal cert status / expiry in `bangor-admin`?>>

## People

- <<CONFIRM: product owner / PM for bangor-admin>>
- <<CONFIRM: other engineers on the repo besides you>>
- <<CONFIRM: business stakeholder to escalate franchise-ops questions to>>

## Roadmap signal

- <<CONFIRM: next 1–2 planned slices after current work, so design can leave room for them without over-engineering>>
