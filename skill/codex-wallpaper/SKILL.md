---
name: codex-wallpaper
description: Control the installed Codex desktop wallpaper tool on Windows. Use when the user wants to change Codex background images, adjust wallpaper brightness, blur or transparency, restore the default appearance, or open wallpaper settings. Applies to Codex wallpaper, not the Windows desktop wallpaper.
---

# Codex wallpaper

The local settings application and this skill share one configuration. Use this skill's `scripts/wallpaper.ps1`; it resolves the application through `location.json`. Do not depend on the current working directory or guess an installation path.

Run the bundled wrapper through Windows PowerShell, using its absolute path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<absolute-skill-directory>\scripts\wallpaper.ps1' -Status
```

Read status before a relative adjustment. Send only the requested changes; the wrapper preserves other settings.

| Request | Wrapper parameters |
|---|---|
| Choose an image | `-ImagePath 'C:\Pictures\wallpaper.jpg'` |
| Brightness 80% | `-Brightness 0.8` |
| Blur | `-Blur 4` (0–30 pixels) |
| Background transparency 75% | `-Transparency 75` (10–100; higher reveals more of the image) |
| Entire window / chat area | `-Scope window` / `-Scope chat` |
| Restore default appearance | `-Disable` |
| Re-enable the saved wallpaper | `-Enable` |
| Open the settings application | `-OpenSettings` |
| Start Codex with wallpaper | `-Start` |

Combine adjustment parameters in one invocation. `-Status` is for reading only and cannot accompany adjustments. Images must have an absolute path, contain PNG, JPEG or WebP bytes, and be at most 20 MiB. Setting an image also enables wallpaper. Disabling preserves the chosen image and adjustments.

The returned JSON contains `settings` and `live`. After a successful change, confirm that `settings` matches the requested values before reporting them saved. Confirm **real-time application only when `live.applied` is true**: the loader has acknowledged this exact settings revision, its heartbeat is fresh, and its process is running. If the values match but `live.applied` is false, say the settings were saved but are awaiting application. A read-only query describes the current state; it does not establish that a requested change was made. A file saying `state: active` alone can be stale or acknowledge an older revision. Re-read `-Status` after a short wait if synchronization is pending.

When disconnected, settings remain saved. Start the loader when the user requests startup; if it reports `waiting-for-codex-exit`, explain that Codex needs a full tray exit before the loader automatically reopens it. Never force-close Codex to change wallpaper. This tool uses the original installation without editing its program files.

If the software folder has moved, run its `安装桌面入口与Skill.cmd` to refresh the skill location. Surface an absent installation or validation error instead of inventing a successful result.
