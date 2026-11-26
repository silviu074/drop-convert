# Drop Convert

Convert files without opening them. Drop a file on a small orange bubble, pick a format from the
round menu, and the converted copy is saved next to the original.

<p align="center"><img src="docs/demo.gif" width="300" alt="Dropping a video, a Word file and an image on the bubble and picking a format"></p>

<p align="center">
  <img src="docs/menu-1.png" width="260" alt="Menu for a video: MP4, MOV, WEBM, GIF, MP3, WAV">
  <img src="docs/menu-2.png" width="260" alt="Menu for a Word file: PDF, ODT, RTF, TXT">
  <img src="docs/menu-3.png" width="260" alt="Menu for an image: JPG, WEBP, BMP">
</p>

Full demo video: [docs/demo.mp4](docs/demo.mp4)

## What it does

- A floating bubble that stays on top. Drag it anywhere; it remembers the spot.
- Drop one file or many. The round menu only shows formats that fit the file.
- Point at the orange ring (or the **ALL** tab) to get every format at once.
- The original is never changed, and nothing is overwritten (`clip (2).mp4`).
- Files are converted on your own computer and never uploaded. There is no account.

| You drop | You can get |
|---|---|
| Video: MP4, MOV, MKV, AVI, WEBM, M4V, WMV, FLV | MP4, MOV, WEBM, GIF, MP3, WAV |
| GIF | MP4, MOV, WEBM |
| Audio: MP3, WAV, FLAC, M4A, OGG, AAC, OPUS, WMA | MP3, WAV, FLAC, M4A, OGG |
| Image: PNG, JPG, WEBP, BMP, TIFF | PNG, JPG, WEBP, BMP |
| Document: DOCX, DOC, RTF, ODT, TXT | PDF, DOCX, ODT, RTF, TXT |
| PDF | DOCX, TXT, or one JPG / PNG per page |

## Install

### Windows 10 / 11

1. Download **drop-convert-windows.zip** from [Releases](../../releases) and unzip it.
2. Double-click **Install Drop Convert.cmd**. It builds the app from source with the C# compiler
   that comes with Windows (no .exe is downloaded) and adds Desktop and Start menu shortcuts.
   It offers to install free ffmpeg with winget if you don't have it.
3. Open **Drop Convert** from the Desktop or Start menu.

Needs: [ffmpeg](https://ffmpeg.org) for video, audio and images (free), and Microsoft Word 2016 or
newer for documents and PDF to Word. Without one of them, those formats show **Failed**; the rest
still work.

More in [windows/README.md](windows/README.md).

### Mac (untested)

The Mac version is written in Swift and builds on your Mac with Apple's free Command Line Tools.
**It has not been run on a real Mac yet.** Download **drop-convert-mac.zip** from
[Releases](../../releases) and follow [mac/README.md](mac/README.md). Bug reports are welcome.

## Build it yourself

Windows: the whole app is one file, [windows/DropConvert.cs](windows/DropConvert.cs).
Run [windows/build.cmd](windows/build.cmd) to make DropConvert.exe. Nothing to install.

Mac: [mac/DropConvert.swift](mac/DropConvert.swift), built by the installer with `swiftc`.

## How it was made

Made with AI. I described the app in plain words and Claude Code wrote the code, the installers and
the demo. I decided what the app should do. Every format was tested on Windows; the Mac version
has not been run yet.

## Credits

- Idea inspired by Tangerine, a file converter app for Mac. No code or art was copied; Drop Convert was
  written from scratch.
- [ffmpeg](https://ffmpeg.org) does the video, audio and image conversions. It is not included: the installer
  offers to get it with winget (the Gyan.dev build) on Windows or Homebrew on Mac. ffmpeg is free software
  under the LGPL/GPL.
- Microsoft Word does the document conversions, and the PDF reader built into Windows turns PDFs into images.
  Both are used as they are on your computer, not included.
- The icon, the bubble and the round menu are drawn by the app's own code (windows/make-icon.ps1 for the icon).
- The demo was recorded on Windows with sample files made for it. It shows File Explorer and the usual file
  icons for Word, PDF and VLC, which belong to their owners.

## License

[MIT](LICENSE)
