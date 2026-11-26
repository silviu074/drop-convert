# Drop Convert for Mac

Convert files without opening them. Drop a file on the orange bubble, pick a format from the
round menu, and the converted copy appears next to the original.

**Untested:** this Mac version was written on Windows and has not been run on a Mac yet.
If the build or a conversion fails, paste the Terminal text or the error into Claude Code and ask it to fix it.

## Install

1. Unzip this folder anywhere.
2. Double-click **Install Drop Convert.command**. A Terminal window opens and builds the app on your Mac.
   - The first time, macOS may ask to install Apple's free **Command Line Tools** (they contain the
     Swift compiler). Click Install, wait until it finishes, then run the installer again.
   - If macOS says it can't check the file: open System Settings > Privacy & Security, scroll down
     and click **Open Anyway**. Or open Terminal, type `bash` and a space, drag the file into the
     window and press Return.
   - It offers to install free **ffmpeg** with Homebrew, if you have Homebrew.
3. The bubble appears at the bottom right. Next time, open **Drop Convert** from Launchpad or Spotlight.

The first time you convert a file in Desktop, Documents or Downloads, macOS may ask if Drop Convert
can use that folder. Click **Allow**, or it can't save the copy there.

To remove it, double-click **Uninstall Drop Convert.command**.

## Using it

| To do this | Do this |
|---|---|
| Convert a file | Drag the file onto the bubble, then click a format in the round menu |
| Get every format at once | Point at the orange ring around the menu (or its **ALL** tab): every slice lights up. Click to make a copy in every format |
| Convert several files | Select them all and drag them onto the bubble together |
| Move the bubble | Drag it. It reopens in the same spot next time |
| Close the round menu | Click outside it, click its middle, or press Esc |
| Quit the app | Right-click (or Control-click) the bubble and choose **Quit Drop Convert** |

While a file converts, the middle of the menu shows a spinning ring. When it finishes it shows
**Saved** and the menu closes by itself. If something goes wrong it shows **Failed** with the reason.

## Where the files go

The new file is saved **in the same folder as the original**, with the same name and the new
extension. The original is never changed. If a file with that name already exists, a number is
added instead of overwriting it, for example `clip (2).mp4`.

## What it can convert

| You drop | You can get |
|---|---|
| **Video**: MP4, MOV, MKV, AVI, WEBM, M4V, WMV, FLV | MP4, MOV, WEBM, GIF, or just the sound as MP3 or WAV |
| **GIF** | MP4, MOV, WEBM |
| **Audio**: MP3, WAV, FLAC, M4A, OGG, AAC, OPUS, WMA | MP3, WAV, FLAC, M4A, OGG |
| **Image**: PNG, JPG, WEBP, BMP, TIFF | PNG, JPG, WEBP, BMP |
| **Document**: DOCX, DOC, RTF, ODT, TXT | PDF, DOCX, ODT, RTF, TXT |
| **PDF** | DOCX (text only), TXT, or one JPG / PNG image per page |

Good to know:

- **GIF** output is limited to 480 px wide and 12 frames per second to keep the size sane.
- **JPG** has no transparency, so see-through parts of an image become white.
- **Documents to PDF**: with LibreOffice installed (free), the PDF looks close to the original.
  Without it, macOS lays the text out itself: fonts and paragraphs stay, but complex layouts
  (columns, text boxes, headers) are simplified.
- **PDF to DOCX** keeps only the text (with basic fonts), not the page layout. There is no free
  Mac tool that rebuilds a PDF's layout as Word does on Windows.
- **Scanned PDFs** are pictures of pages, so they have no text to extract.
- **PDF to images**: about 1700 px wide per page. A one-page PDF gives `name.png`; longer PDFs
  give `name - page 1.png`, `name - page 2.png`, and so on.

## How it works

Drop Convert is a small Mac app built from one file, **DropConvert.swift**. Your files never leave your Mac.

- **Video, audio and images**: [ffmpeg](https://ffmpeg.org) (free), installed with Homebrew.
- **Documents**: textutil, built into macOS. PDFs from documents: LibreOffice if installed,
  otherwise macOS's own text layout.
- **PDF to text and images**: PDFKit, built into macOS.

## Requirements

- macOS 13 or newer (Apple Silicon or Intel).
- Apple's free Command Line Tools, to build it (the installer asks for them).
- **ffmpeg** for video, audio and images. Without it, those show **Failed**; documents and PDFs still work.

## Changing the app

Edit **DropConvert.swift**, then run **Install Drop Convert.command** again. It quits the running
app, rebuilds it and starts the new one.
