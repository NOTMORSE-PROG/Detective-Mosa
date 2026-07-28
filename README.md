# Detective Mosa

A 2D narrative mobile game about media and information literacy, built in Godot 4.7.

Mosa is the most notorious gossip in Barangay Masipag. After spreading an unverified
rumour that gets an innocent neighbour falsely accused, she's recruited by a retired
community journalist to investigate the rumours she once spread carelessly — and to
learn how to check before sharing.

## Requirements

- [Godot 4.7.1 (stable)](https://godotengine.org/download), standard build
- Android SDK + NDK and a JDK, for Android export (see Godot's
  [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) guide)

## Opening the project

1. Clone this repository
2. Open Godot, choose **Import**, and select this folder's `project.godot`
3. Run the project from the editor (F5)

## Building

Use Godot's **Project → Export** dialog with the Android preset, or the equivalent
`--export-debug` / `--export-release` command-line flags. You will need your own
Android debug keystore and export template installation; see Godot's export
documentation linked above.
