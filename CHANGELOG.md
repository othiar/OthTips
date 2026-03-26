# Changelog

All notable changes to `OthTips` should be recorded in this file.

## 0.2.8

- Fixed a stale hostile corpse/gather status line that could carry over when moving quickly between targets.

## 0.2.7

- Added a stable `OthTips.zip` release asset alongside the versioned package for better updater compatibility.

## 0.2.6

- Moved corpse and gather-status cleanup onto the modern tooltip data pipeline with `TooltipDataProcessor` pre-calls.
- Replaced the remaining unit reapply polling with `TOOLTIP_DATA_UPDATE` handling keyed by tooltip data instance.
- Fixed duplicate corpse lines on some attackable dead targets without regressing the recent performance improvements.

## 0.2.5

- Added a maintained `CHANGELOG.md` for release notes.
- Updated the GitHub release workflow to publish notes from the matching changelog section.

## 0.2.4

- Improved corpse gather-tag detection for skinning, mining, herbalism, and engineering variants.
- Broadened matching to catch more overloaded profession spawn tooltip text.

## 0.2.3

- Added GitHub tag-driven release automation.
- Trimmed the bundled Inter font set to the supported non-italic weights.

## 0.2.2

- Added broader gather profession detection for corpse tooltip tags.

## 0.2.1

- Updated hostile tooltip fallback behavior and packaged release cleanup.

## 0.2.0

- Stabilized hostile tooltip rendering fallback for attackable targets.
- Removed temporary hostile-tooltip debug scaffolding after validation.

## 0.1.9

- Added switchable Inter font options in the settings panel.
- Set new installs to default to `Inter SemiBold`.

## 0.1.8

- Added comments and module-level documentation across the split addon files.

## 0.1.7

- Added cursor gap control for mouse-anchored tooltips.

## 0.1.6

- Refined the modern settings panel layout and control alignment.

## 0.1.5

- Updated addon metadata and release packaging.
