# Coonch (Flutter)

This repository contains a scaffolded Flutter app for the Coonch mobile app.

What I created:
- Minimal Flutter scaffold with `lib/main.dart` and a small set of screens (Splash → Login → Home).
- `lib/src/services/api_service.dart` — a simple HTTP client to call your Django backend. Set `baseUrl` to your Django API root.
- `pubspec.yaml` with recommended dependencies: `provider`, `http`, `flutter_svg`, `google_fonts`.

Next steps for me (I can take these next if you want):
- Export assets (SVG/PNG) and fonts from Figma and drop them into `assets/images/` and `assets/fonts/`.
- I will then implement UI screens exactly matching the Figma designs and wire the real API endpoints.

How to run locally:
1. Install Flutter SDK and ensure `flutter` is on your PATH.
2. From this folder, run:

```powershell
flutter pub get
flutter run
```

API setup:
- Replace the placeholder `baseUrl` when constructing `ApiService` with your Django API base (for example `https://api.yourdomain.com/` or `http://10.0.2.2:8000/` for Android emulator).

If you want me to continue, grant access to the Figma file (or export the assets) so I can implement the visual screens and refine the design/spacing/colors to match the Figma file exactly.
