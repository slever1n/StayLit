# StayLit

A tiny Windows tray app that keeps your PC awake and stops it from locking itself.

## How it works

1. Calls `SetThreadExecutionState` so Windows doesn't sleep or turn off the display.
2. Every 50 seconds it sends an invisible **F15** key press to reset the idle timer
   (prevents screensaver / inactivity lock). No normal app reacts to F15.

## Usage

- Run `StayLit.exe` — an icon appears in the system tray.
- **Left-click** the icon to pause / resume (grey icon = paused).
- **Right-click → Exit** to quit; normal sleep/lock behaviour is restored.
- To start with Windows: `Win+R` → `shell:startup` → drop a shortcut to `StayLit.exe` in there.

## Build

No SDK needed — uses the C# compiler that ships with Windows (.NET Framework 4.x):

```bat
build.bat
```

`build.bat` generates `app.ico` from `icon-source.jpg` (via `make-icon.ps1`) if missing,
then compiles `StayLit.exe`.

## Buy me a coffee

https://buymeacoffee.com/sleverin
