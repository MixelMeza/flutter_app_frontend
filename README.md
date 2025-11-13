# LivUp (formerly app_movil)

This project now uses the app name "LivUp". Add your app logo file at `assets/logo.png` to be displayed on the splash screen and inside the login UI.

Quick steps to see the splash and login locally:

1. Put your PNG logo at `assets/logo.png` (recommended size ~512x512). The project already lists this asset in `pubspec.yaml`.
2. Run:

```cmd
cd /d C:\Proyectos_flutter\Proyectos\app_movil
flutter clean
flutter pub get
flutter run
```

Notes:
- If you prefer a native launch/splash (no Flutter frame), consider the `flutter_native_splash` package (I can add a config for it if you want).
- For Android native splash customization, you'd put drawable resources under `android/app/src/main/res/` and edit `launch_background.xml` / `styles.xml`.
- For iOS native splash, replace the LaunchScreen storyboard or add images to `Assets.xcassets` as needed.
