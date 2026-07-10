# Mobile Deployment Guardrails

These rules exist because a previous mobile web fallback changed the desktop
play experience. When asked to make mobile deployment work, preserve the PC web
build unless the user explicitly approves changing it.

## Non-Negotiable Rules

1. Do not change the public desktop route (`/Project_1/`) to a mobile fallback.
2. Do not replace the Godot desktop web export with hand-written Canvas,
   Phaser, HTML, or another runtime.
3. Do not add viewport-width redirects that can catch desktop browsers,
   desktop emulation, tablets, or resized windows.
4. Do not give the user a mobile-only URL as the main game URL.
5. Do not edit `docs/index.html` for mobile behavior unless the diff is proven
   to preserve desktop behavior and the user explicitly accepts the risk.
6. Do not commit or push a mobile fix until desktop and mobile routes have both
   been verified separately.

## Required Isolation Model

Use one of these patterns only:

- Keep `/Project_1/` as the existing desktop Godot web build.
- Put mobile experiments behind an explicit separate route such as
  `/Project_1/mobile/`, `/Project_1/mobile-test/`, or a separate branch/site.
- Prefer native Android/iOS exports for real mobile playability instead of a
  browser fallback when performance or compatibility is the issue.

Any mobile route must be opt-in. The desktop route must never auto-redirect to
it unless the user explicitly asks for a production mobile-first site.

## Verification Checklist

Before committing:

- `git diff --name-status` shows no unexpected changes to desktop artifacts.
- Desktop URL still loads the Godot build and references `game-smooth.pck`.
- Desktop URL does not reference `mobile.html`, `mobile-game.js`, or mobile-only
  redirect logic.
- Mobile experiment URL, if any, is separate from the desktop URL.
- Browser checks include at least one desktop viewport and one mobile viewport.
- Screenshots are inspected for both routes.
- If deployment is involved, deployed HTTP checks confirm the same separation.

Useful checks:

```powershell
rg -n "mobile.html|mobile-game|narrowViewport|location.replace" docs\index.html
git diff --name-status
```

Expected result for a desktop-safe mobile experiment:

- `docs/index.html` has no mobile redirect.
- Any mobile work lives in a separate path.
- The public desktop URL remains visually identical unless the user approved a
  desktop visual change.

## If Mobile Web Fails

Do not patch around it by rewriting the game in JavaScript. First diagnose:

- Browser console errors.
- Whether WebGL 2 is available.
- Whether the `.wasm` and `.pck` files download successfully.
- Whether loading fails from payload size, initialization time, memory, or
  unsupported browser/GPU behavior.

If the root cause is Godot Web export compatibility or mobile performance,
recommend one of these, in order:

1. Native Android export for Android phones.
2. Native iOS export for iPhone/iPad.
3. Optimized Godot web export with reduced payload size and mobile-specific
   settings, still served separately from the desktop route.

## Commit Policy

For mobile deployment work, use small commits with clear boundaries:

- One commit for diagnosis or documentation.
- One commit for mobile-only export/build changes.
- One commit for deployment plumbing.

Never bundle desktop visual/gameplay changes with mobile deployment fixes.
