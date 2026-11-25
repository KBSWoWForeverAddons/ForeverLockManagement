# Changelog

## [v1.1.1] - 2026-11-25

### Fixed
- Switched speech-enabled hub and drawer buttons (Demon summons, Ritual of Summoning, Ritual of Souls, Soulstone, and Mount) to native secure macro text (`/cast` or `/use` + `/s`, `/p`, `/ra`, or `/i`) so announcements reliably appear in `/say` when solo outdoors and in party/raid chat when grouped without falling back to local `[FLM]` text.
- Automatically refresh hub speech macros on `GROUP_ROSTER_UPDATE`, speech option toggles, and custom speech saves/resets, with deduplication against `UNIT_SPELLCAST_SENT`.

## [v1.1.0] - 2026-11-25

### Added
- Added **Auto-close drawers after selection** option under Hub Layout (enabled by default) so Demons, Curses, Buffs & Utility, and Weapon Stones drawers close automatically after clicking a spell or stay open when unchecked.

### Fixed
- Fixed secure post-click drawer closing (supporting both key-down and key-up `ActionButtonUseKeyDown` settings, including in combat).
- Enabled real `/say` announcements outdoors when casting speech spells from Forever Lock Management hub and drawer buttons via hardware-click handling, while keeping local chat fallback for restricted non-hardware casts.

## [v1.0.1] - 2026-11-25

### Fixed
- Prevented `ADDON_ACTION_BLOCKED` errors when Warlock speech triggers outdoors while solo or during chat messaging lockdown; solo outdoor announcements now display locally in chat, while instance, party, raid, and instance-group channels continue broadcasting normally.
- Added `"INSTANCE_CHAT"` channel support for queued dungeon/raid/battleground groups and guarded Soulstone whispers on group membership.

## [v1.0.0] - 2026-11-24

### Added
- Vertical Warlock hub (`72x98`) with live Soul Shard capacity fill meter and bag indicator.
- Quick-access buttons for Healthstone / Ritual of Souls, Soulstone, Mount, and Shard Manager.
- Combat-safe pull-out drawers for Demons, Curses, Buffs & Utility, and Weapon Stones (Firestone / Spellstone).
- Soul Shard bag assignment (Bags 1–5), out-of-combat auto-sorting, bag-capacity / custom limit tracking, and one-click excess shard cleanup.
- Customizable event speech announcements (Ritual of Summoning, Soulstone, Ritual of Souls, Demon Summons, Mount) with in-game Speech Editor and local chat preview.
- Movable center-screen warning icons for Shadow Trance (Nightfall), Backlash, Demon / Elemental targets, and Anti-Fear (with Secret Values safety guards).
