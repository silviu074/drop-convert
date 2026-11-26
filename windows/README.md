# Drop Convert

Convert files without opening them. Drop a file on the orange bubble, pick a format from the
round menu, and the converted copy appears next to the original.

## Install

1. Unzip this folder anywhere.
2. Double-click **Install Drop Convert.cmd**. It builds the app on your PC with the C# compiler that
   comes with Windows, adds Desktop and Start menu shortcuts, and offers to install free ffmpeg.
3. Open **Drop Convert** from your Desktop or Start menu.

To remove it, double-click **Uninstall Drop Convert.cmd**.

## Using it

| To do this | Do this |
|---|---|
| Start it | Double-click **DropConvert.exe** (or its Desktop / Start menu shortcut) |
| Convert a file | Drag the file onto the bubble, then click a format in the round menu |
| Get every format at once | Point at the orange ring around the menu (or its **ALL** tab): it glows and every slice lights up. Click to make a copy in every format the menu shows |
| Convert several files | Select them all and drag them onto the bubble together |
| Move the bubble | Hold the left mouse button on it and drag. It reopens in the same spot next time (saved in **position.txt** next to the app; delete that file to reset it) |
| Close the round menu | Click outside it, click its middle, or press Esc |
| Quit the app | Right-click the bubble and choose **Quit Drop Convert** |

Only one bubble runs at a time. Starting the app again while it is open does nothing.

While a file converts, the middle of the menu shows a spinning ring. When it finishes it shows
**Saved** and the menu closes by itself. If something goes wrong it shows **Failed** with the
reason; click outside the menu to close it.

## Where the files go

The new file is saved **in the same folder as the original**, with the same name and the new
extension. The original is never changed. If a file with that name already exists, a number is
added instead of overwriting it, for example `clip (2).mp4`.

## What it can convert

The menu only shows the formats that make sense for the file you dropped.

| You drop | You can get |
|---|---|
| **Video**: MP4, MOV, MKV, AVI, WEBM, M4V, WMV, FLV | MP4, MOV, WEBM, GIF, or just the sound as MP3 or WAV |
| **GIF** | MP4, MOV, WEBM |
| **Audio**: MP3, WAV, FLAC, M4A, OGG, AAC, OPUS, WMA | MP3, WAV, FLAC, M4A, OGG |
| **Image**: PNG, JPG, WEBP, BMP, TIFF | PNG, JPG, WEBP, BMP |
| **Document**: DOCX, DOC, RTF, ODT, TXT | PDF, DOCX, ODT, RTF, TXT |
| **PDF** | DOCX (editable Word file), TXT, or one JPG / PNG image per page |

Good to know:

- **GIF** output is limited to 480 px wide and 12 frames per second to keep the size sane.
  Long videos still make big GIFs.
- **JPG** has no transparency, so see-through parts of an image become white.
- **PDF to DOCX** rebuilds the PDF as an editable document. Simple documents come out well;
  complex layouts may shift a little.
- **PDF to images**: a one-page PDF gives `name.png`; longer PDFs give `name - page 1.png`,
  `name - page 2.png`, and so on.
- If you drop a mix of file types, the menu follows the first file, and only files of that
  same type are converted.

## How it works

Drop Convert is a small Windows program. It does the conversions with tools that are already
on the computer, so your files never leave it:

- **Video, audio and images**: [ffmpeg](https://ffmpeg.org) (free).
- **Documents, and PDF to DOCX / TXT**: Microsoft Word, running hidden in the background.
  You never see a Word window. While it converts a PDF, the app briefly turns off Word's
  "Word will now convert your PDF" question and then restores your setting.
  If Word ever gets stuck, the app closes its own hidden Word after 2 minutes; it never
  touches a Word window you have open.
- **PDF to JPG / PNG**: the PDF reader built into Windows.

## Requirements

- Windows 10 or 11.
- **ffmpeg** installed and on the PATH, for video, audio and images.
- **Microsoft Word** (2016 or newer), for documents and PDF to DOCX / TXT.

Without ffmpeg or Word, those conversions show **Failed**; the others still work.

## Changing the app

The whole app is one file, **DropConvert.cs**. After editing it, run **build.cmd** to make a new
**DropConvert.exe** (quit the running app first). It uses the C# compiler that comes with
Windows, so nothing needs to be installed. **make-icon.ps1** redraws the icon (**app.ico**).
