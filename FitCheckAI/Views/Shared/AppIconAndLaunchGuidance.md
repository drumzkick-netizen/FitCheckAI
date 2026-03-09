# App Icon & Launch Screen Guidance

## App Icon Concept

- **Base:** Dark background (match `AppColors.background` or slightly lighter).
- **Mark:** Glowing score ring (partial circle, ~3/4 arc) in accent purple.
- **Style:** Clean, minimal, no text. Single recognizable shape.
- **Accent:** Subtle gradient (purple to pink) aligned with `AppColors.accent` / `AppGradients.primary`.
- **Reference:** Use `BrandMarkView` in the app as a visual reference for the ring shape and glow.

## Launch Screen (Xcode / Assets)

1. **Launch Screen:** Use a Launch Storyboard or Asset Catalog launch image.
2. **Background:** Same dark as app (`#141420` or `AppColors.background`).
3. **Content:** Centered app name "FitCheckAI" (white), optional small tagline (muted). No animation required at launch; the in-app `SplashView` handles the branded transition after the window appears.
4. **Alternative:** Use a static launch image that matches `SplashView` (dark + centered logo/text) so the handoff from system launch to in-app splash feels seamless.
