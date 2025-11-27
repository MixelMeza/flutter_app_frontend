Instructions to bundle Poppins and Inter fonts

1) Download the TTF files (from Google Fonts) and place them under `assets/fonts/` with these filenames:

  - assets/fonts/Poppins-Regular.ttf
  - assets/fonts/Poppins-Medium.ttf
  - assets/fonts/Poppins-SemiBold.ttf
  - assets/fonts/Poppins-Bold.ttf
  - assets/fonts/Poppins-ExtraBold.ttf

  - assets/fonts/Inter-Regular.ttf
  - assets/fonts/Inter-Medium.ttf
  - assets/fonts/Inter-SemiBold.ttf
  - assets/fonts/Inter-Bold.ttf

2) Run:

```bash
flutter pub get
flutter clean
flutter pub get
``` 

3) Run the app (or `flutter run --release`) and verify typography.

Notes:
- Bundling fonts as assets gives exact control over weights and rendering.
- If you prefer, you can download the fonts from Google Fonts: https://fonts.google.com/
  Choose Poppins and Inter, then download the family and copy the .ttf files to the paths above.
