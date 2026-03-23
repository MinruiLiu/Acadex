# Acadex Flutter App (Scaffold)

This folder contains a simple iOS-style Flutter UI scaffold.

## 1) Install Flutter (macOS)

```bash
brew install --cask flutter
echo 'export PATH="$PATH:/opt/homebrew/Caskroom/flutter/latest/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
flutter doctor
```

If the cask path is different on your machine, use:

```bash
brew info --cask flutter
```

## 2) Generate platform folders (iOS + Android)

Run from this `mobile_app` directory:

```bash
flutter create .
flutter pub get
```

## 3) Interactive preview

### iOS Simulator

```bash
open -a Simulator
flutter run -d ios
```

### Android Emulator

```bash
flutter emulators
flutter emulators --launch <emulator_id>
flutter run -d android
```

### Hot reload (live interactive updates)

- Press `r` in terminal for hot reload
- Press `R` for hot restart

## 4) Web quick preview (optional)

For very fast interaction preview in browser:

```bash
flutter config --enable-web
flutter run -d chrome
```
