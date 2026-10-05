# boneFarm

`boneFarm.ash` farms **Skeleton of Crimbo Past** knucklebones at **The Skeleton Store** until KoLmafia's daily `_knuckleboneDrops` counter reaches 100 or only 2 adventures remain.

## Install

In the KoLmafia gCLI:

```text
git checkout donCannoli-burns/boneFarm main
```

Then verify and run:

```text
verify boneFarm.ash
call boneFarm.ash
```

## Requirements

- Skeleton of Crimbo Past familiar.
- `small peppermint-flavored sugar walking crook`.
- An equippable custom outfit named `bonefarm`.
- A mood named `bonefarm` containing buffs/effects only. **Remove any `mcd 10` / `mcd 11` trigger from this mood; boneFarm now owns MCD selection itself.**
- A CCS named `bonefarm`.

The outfit can still use KoLmafia's hidden outfit modifiers, for example:

```text
bonefarm f=Skeleton of Crimbo Past e=small peppermint-flavored sugar walking crook m=bonefarm
```

The script explicitly selects the familiar, familiar equipment, mood, and CCS as a safety check, so those outfit modifiers are optional.

## What changed from the original draft

- Uses `_knuckleboneDrops` as the authoritative daily 0-100 counter. KoLmafia also increments this counter for the five daily rest knucklebones, so `_knuckleboneRests` must not be added to it.
- Re-reads the live knucklebone counter after every adventure instead of snapshotting it once before the run.
- Farms one adventure at a time, so it stops promptly at the daily cap.
- Preserves 2 adventures, matching the original script's intent.
- Replaces the stale `turns_spent > KBneeded_adv` watchdog with a no-progress guard.
- Uses `try/finally` so the original familiar, familiar equipment, outfit checkpoint, mood, CCS, and MCD level are restored even if farming aborts.
- Owns MCD while farming: level 11 for Mysticality/Little Canadia signs, level 10 otherwise; if MCD is unavailable in the current path/limit mode it leaves the current level unchanged.
- Keeps `boneTrack.ash` integration optional and restores `boneTrackEnableWiki` after each tracker call.
- Unlocks The Skeleton Store through the Meatsmith quest when needed.

## Notes

`boneTrack.ash` is optional. If it is installed, boneFarm calls it before and after farming with `boneTrackEnableWiki=false`; if it is not installed, farming continues normally.

This repository is laid out with the script under `scripts/`, which is the directory KoLmafia's Git installer copies into your local `scripts/` directory.
