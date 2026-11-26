// Drop Convert for Mac: a small orange bubble. Drop files on it, pick a format from the round menu,
// and the converted copy is saved next to the original. Video, audio and images use ffmpeg;
// documents and PDFs use tools built into macOS (textutil, PDFKit), or LibreOffice for PDFs if it is installed.
// Build: swiftc -O DropConvert.swift -o DropConvert   (the installer does this for you)
import AppKit
import PDFKit

// ---------------------------------------------------------------- formats

enum Tool { case ffmpeg, textutil, docPdf, pdfText, pdfDocx, pdfImage }

struct Fmt {
    let ext: String, label: String, sub: String
    let args: [String]
    let tool: Tool
    init(_ ext: String, _ label: String, _ sub: String, _ args: [String] = [], _ tool: Tool = .ffmpeg) {
        self.ext = ext; self.label = label; self.sub = sub; self.args = args; self.tool = tool
    }
}

enum Conv {
    static let video = ["mp4", "mov", "mkv", "avi", "webm", "m4v", "wmv", "flv", "gif"]
    static let audio = ["mp3", "wav", "flac", "m4a", "ogg", "aac", "opus", "wma"]
    static let image = ["png", "jpg", "jpeg", "webp", "bmp", "tif", "tiff"]
    static let doc = ["docx", "doc", "rtf", "odt", "txt"]

    static let even = ["-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2"]
    static let mp3 = ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
    static let wav = ["-vn", "-c:a", "pcm_s16le"]

    static let videoOut = [
        Fmt("mp4", "MP4", "Video", even + ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]),
        Fmt("mov", "MOV", "Video", even + ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k"]),
        Fmt("webm", "WEBM", "Web video", even + ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-row-mt", "1", "-deadline", "good", "-cpu-used", "4", "-c:a", "libopus"]),
        Fmt("gif", "GIF", "Animation", ["-vf", "fps=12,scale='min(480,iw)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"]),
        Fmt("mp3", "MP3", "Audio only", mp3),
        Fmt("wav", "WAV", "Audio only", wav),
    ]
    static let audioOut = [
        Fmt("mp3", "MP3", "Audio", mp3),
        Fmt("wav", "WAV", "Audio", wav),
        Fmt("flac", "FLAC", "Lossless", ["-vn", "-c:a", "flac"]),
        Fmt("m4a", "M4A", "Audio", ["-vn", "-c:a", "aac", "-b:a", "192k"]),
        Fmt("ogg", "OGG", "Audio", ["-vn", "-c:a", "libvorbis", "-q:a", "5"]),
    ]
    static let imageOut = [
        Fmt("png", "PNG", "Image", ["-frames:v", "1", "-update", "1"]),
        // JPG has no transparency: put see-through parts on white instead of black
        Fmt("jpg", "JPG", "Photo", ["-filter_complex", "[0]format=rgba,split[a][b];[a]drawbox=c=white:t=fill[w];[w][b]overlay,format=yuvj444p", "-frames:v", "1", "-update", "1", "-q:v", "2"]),
        Fmt("webp", "WEBP", "Web image", ["-frames:v", "1", "-update", "1", "-c:v", "libwebp", "-quality", "90", "-pix_fmt", "yuva420p"]),
        Fmt("bmp", "BMP", "Bitmap", ["-frames:v", "1", "-update", "1", "-pix_fmt", "bgra"]),
    ]
    static let docOut = [
        Fmt("pdf", "PDF", "Document", [], .docPdf),
        Fmt("docx", "DOCX", "Word", [], .textutil),
        Fmt("odt", "ODT", "OpenDocument", [], .textutil),
        Fmt("rtf", "RTF", "Rich text", [], .textutil),
        Fmt("txt", "TXT", "Plain text", [], .textutil),
    ]
    static let pdfOut = [
        Fmt("docx", "DOCX", "Text only", [], .pdfDocx),
        Fmt("txt", "TXT", "Plain text", [], .pdfText),
        Fmt("jpg", "JPG", "Pages", [], .pdfImage),
        Fmt("png", "PNG", "Pages", [], .pdfImage),
    ]

    static func ext(_ url: URL) -> String {
        let e = url.pathExtension.lowercased()
        return e == "jpeg" ? "jpg" : e == "tif" ? "tiff" : e
    }

    static func kind(_ url: URL) -> String? {
        let e = ext(url)
        if video.contains(e) { return "video" }
        if audio.contains(e) { return "audio" }
        if image.contains(e) { return "image" }
        if doc.contains(e) { return "doc" }
        if e == "pdf" { return "pdf" }
        return nil
    }

    static func options(_ url: URL) -> [Fmt] {
        let e = ext(url)
        let all: [Fmt]
        switch kind(url) {
        case "video": all = videoOut
        case "audio": all = audioOut
        case "image": all = imageOut
        case "doc": all = docOut
        case "pdf": all = pdfOut
        default: all = []
        }
        // a GIF has no sound, so no audio choices for it
        return all.filter { $0.ext != e && !(e == "gif" && $0.args.first == "-vn") }
    }

    // name.ext next to the original, or "name (2).ext" if that exists
    static func outPath(_ dir: URL, _ name: String, _ ext: String) -> URL {
        var url = dir.appendingPathComponent(name + "." + ext)
        var i = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent(name + " (\(i))." + ext)
            i += 1
        }
        return url
    }

    static func outPath(_ file: URL, _ ext: String) -> URL {
        outPath(file.deletingLastPathComponent(), file.deletingPathExtension().lastPathComponent, ext)
    }

    // Apps opened from Finder don't get the Terminal's PATH, so look in the usual places.
    static func findTool(_ name: String, _ extra: [String] = []) -> String? {
        let dirs = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", "/usr/bin"]
        return (dirs.map { $0 + "/" + name } + extra).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // Runs a program and returns nil on success, or its last error line.
    static func run(_ exe: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        let pipe = Pipe()
        p.standardError = pipe
        p.standardOutput = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return "Could not start " + (exe as NSString).lastPathComponent }
        let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        if p.terminationStatus == 0 { return nil }
        let last = err.split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        return last.isEmpty ? (exe as NSString).lastPathComponent + " failed" : last
    }

    // Returns nil on success, or the error message. Called off the main thread.
    static func convert(_ file: URL, _ f: Fmt) -> String? {
        switch f.tool {
        case .ffmpeg:
            guard let ffmpeg = findTool("ffmpeg") else { return "ffmpeg is missing. In Terminal: brew install ffmpeg" }
            let out = outPath(file, f.ext)
            let err = run(ffmpeg, ["-y", "-hide_banner", "-loglevel", "error", "-i", file.path] + f.args + [out.path])
            if err != nil { try? FileManager.default.removeItem(at: out) }
            return err
        case .textutil:
            return run("/usr/bin/textutil", ["-convert", f.ext, "-output", outPath(file, f.ext).path, file.path])
        case .docPdf:
            return docToPdf(file)
        case .pdfText, .pdfDocx:
            return pdfToText(file, docx: f.tool == .pdfDocx)
        case .pdfImage:
            return pdfToImages(file, f.ext)
        }
    }

    // LibreOffice gives the closest look if it is installed; otherwise macOS lays the text out itself.
    static func docToPdf(_ file: URL) -> String? {
        let out = outPath(file, "pdf")
        if let soffice = findTool("soffice", ["/Applications/LibreOffice.app/Contents/MacOS/soffice"]) {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("dropconvert-" + UUID().uuidString)
            try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmp) }
            let made = tmp.appendingPathComponent(file.deletingPathExtension().lastPathComponent + ".pdf")
            if run(soffice, ["--headless", "--convert-to", "pdf", "--outdir", tmp.path, file.path]) == nil,
               (try? FileManager.default.moveItem(at: made, to: out)) != nil { return nil }
        }
        var result: String? = nil
        DispatchQueue.main.sync {
            guard let text = try? NSAttributedString(url: file, options: [:], documentAttributes: nil) else {
                result = "Could not read this document"; return
            }
            let info = NSPrintInfo(dictionary: [NSPrintInfo.AttributeKey.jobSavingURL: out])
            info.jobDisposition = .save
            info.paperSize = NSPrintInfo.shared.paperSize
            info.topMargin = 56; info.bottomMargin = 56; info.leftMargin = 56; info.rightMargin = 56
            info.horizontalPagination = .fit
            info.verticalPagination = .automatic
            info.isVerticallyCentered = false
            let width = info.paperSize.width - info.leftMargin - info.rightMargin
            let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
            view.appearance = NSAppearance(named: .aqua)   // black text even in dark mode
            view.drawsBackground = false
            view.minSize = NSSize(width: width, height: 0)
            view.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            view.isVerticallyResizable = true
            view.isHorizontallyResizable = false
            view.textStorage?.setAttributedString(text)
            // size the view to the whole text, so every page prints
            if let lm = view.layoutManager, let tc = view.textContainer {
                lm.ensureLayout(for: tc)
                view.setFrameSize(NSSize(width: width, height: ceil(lm.usedRect(for: tc).height) + 1))
            }
            let op = NSPrintOperation(view: view, printInfo: info)
            op.showsPrintPanel = false
            op.showsProgressPanel = false
            if !op.run() || (PDFDocument(url: out)?.pageCount ?? 0) == 0 { result = "Could not make the PDF" }
        }
        return result
    }

    // Text only: PDFs have no paragraphs to rebuild without Word, so the layout is not kept.
    static func pdfToText(_ file: URL, docx: Bool) -> String? {
        guard let pdf = PDFDocument(url: file) else { return "Could not open this PDF" }
        let text = NSMutableAttributedString()
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i)?.attributedString {
                if text.length > 0 { text.append(NSAttributedString(string: "\n\n")) }
                text.append(page)
            }
        }
        if text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "No text in this PDF (scanned pages are images)" }
        if !docx {
            do { try text.string.write(to: outPath(file, "txt"), atomically: true, encoding: .utf8) } catch { return "Could not save the text" }
            return nil
        }
        let rtf = FileManager.default.temporaryDirectory.appendingPathComponent("dropconvert-" + UUID().uuidString + ".rtf")
        defer { try? FileManager.default.removeItem(at: rtf) }
        do {
            let data = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            try data.write(to: rtf)
        } catch { return "Could not convert the text" }
        return run("/usr/bin/textutil", ["-convert", "docx", "-output", outPath(file, "docx").path, rtf.path])
    }

    // One image per page, about 1700 px wide: "name.png" for one page, "name - page 3.png" otherwise.
    static func pdfToImages(_ file: URL, _ ext: String) -> String? {
        guard let pdf = PDFDocument(url: file), pdf.pageCount > 0 else { return "Could not open this PDF" }
        let dir = file.deletingLastPathComponent(), name = file.deletingPathExtension().lastPathComponent
        var result: String? = nil
        DispatchQueue.main.sync {
            for i in 0..<pdf.pageCount {
                // one pool per page, so a long PDF doesn't keep every page bitmap in memory
                let err: String? = autoreleasepool {
                    guard let page = pdf.page(at: i) else { return nil }
                    var size = page.bounds(for: .cropBox).size
                    if page.rotation % 180 != 0 { size = NSSize(width: size.height, height: size.width) }
                    let w = 1700, h = max(1, Int((1700 * size.height / max(size.width, 1)).rounded()))
                    let thumb = page.thumbnail(of: NSSize(width: w, height: h), for: .cropBox)
                    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return "Out of memory" }
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                    NSColor.white.setFill()
                    NSRect(x: 0, y: 0, width: w, height: h).fill()
                    thumb.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
                    NSGraphicsContext.restoreGraphicsState()
                    let data = ext == "jpg" ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                                            : rep.representation(using: .png, properties: [:])
                    let out = outPath(dir, pdf.pageCount == 1 ? name : name + " - page \(i + 1)", ext)
                    guard let d = data, (try? d.write(to: out)) != nil else { return "Could not save page \(i + 1)" }
                    return nil
                }
                if let err = err { result = err; return }
            }
        }
        return result
    }
}

// ---------------------------------------------------------------- look

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

enum Ui {
    static let orange1 = NSColor(hex: 0xFFB347), orange2 = NSColor(hex: 0xFF5E62)
    static let hot = NSColor(hex: 0xFF7A45), lit = NSColor(hex: 0xFF9A62)
    static let ink = NSColor(hex: 0x5A3A2E), subInk = NSColor(hex: 0xA07A68)
    static let sliceFill = NSColor(white: 1, alpha: 0.72)
    static let green = NSColor(hex: 0x2E9E5B), red = NSColor(hex: 0xD9443A)

    static func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, in rect: NSRect,
                     lineBreak: NSLineBreakMode = .byTruncatingMiddle) {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.lineBreakMode = lineBreak
        (s as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                             attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p])
    }
}

// Borderless windows can't take key presses unless they say so.
class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// ---------------------------------------------------------------- bubble

class BubbleView: NSView {
    let holder = CALayer()   // grows while a file is dragged over it
    let orb = CALayer()      // breathes
    var radial: RadialMenu?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
        toolTip = "Drop files here to convert"

        let d: CGFloat = 64
        holder.frame = NSRect(x: (frame.width - d) / 2, y: (frame.height - d) / 2, width: d, height: d)
        orb.frame = holder.bounds
        orb.shadowOpacity = 0.35
        orb.shadowRadius = 9
        orb.shadowOffset = CGSize(width: 0, height: -3)
        orb.shadowPath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: d, height: d), transform: nil)
        let grad = CAGradientLayer()
        grad.frame = orb.bounds
        grad.colors = [Ui.orange1.cgColor, Ui.orange2.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 1)
        grad.endPoint = CGPoint(x: 1, y: 0)
        grad.cornerRadius = d / 2
        orb.addSublayer(grad)
        let arrow = CATextLayer()
        arrow.string = "⇄"
        arrow.fontSize = 28
        arrow.font = NSFont.boldSystemFont(ofSize: 28)
        arrow.foregroundColor = NSColor.white.cgColor
        arrow.alignmentMode = .center
        arrow.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        arrow.frame = CGRect(x: 0, y: (d - 36) / 2, width: d, height: 36)
        orb.addSublayer(arrow)
        holder.addSublayer(orb)
        layer?.addSublayer(holder)

        // slow breathing so it feels alive
        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 1.0
        breathe.toValue = 1.05
        breathe.duration = 1.6
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        orb.add(breathe, forKey: "breathe")
    }

    required init?(coder: NSCoder) { fatalError() }

    func grow(_ on: Bool) {
        holder.setAffineTransform(on ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { grow(true); return .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { grow(false) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        grow(false)
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                               options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty, let win = window else { return false }
        radial?.close()
        let center = NSPoint(x: win.frame.midX, y: win.frame.midY)
        radial = RadialMenu(files: urls, anchor: center)
        return true
    }

    // drag to move; App saves the spot when the window moves
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    // the app is usually in the background: let the first click count
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        let m = NSMenu()
        m.addItem(withTitle: "Quit Drop Convert", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        return m
    }
}

// ---------------------------------------------------------------- round menu

class RadialMenu: NSObject, NSWindowDelegate {
    static let D: CGFloat = 340, R = D / 2, rIn: CGFloat = 64, rOut: CGFloat = 154, ring: CGFloat = 166, pad: CGFloat = 14

    let files: [URL]
    let formats: [Fmt]
    let window: KeyWindow
    let view: MenuView
    var busy = false, closing = false

    init(files: [URL], anchor: NSPoint) {
        self.files = files
        formats = Conv.options(files[0])
        let w = RadialMenu.D + 2 * RadialMenu.pad, h = w + 10
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // center the circle on the bubble, but keep the whole menu on screen
        let x = max(area.minX + 8, min(area.maxX - w - 8, anchor.x - w / 2))
        let y = max(area.minY + 8, min(area.maxY - h - 8, anchor.y - (h - RadialMenu.R - RadialMenu.pad)))
        window = KeyWindow(contentRect: NSRect(x: x, y: y, width: w, height: h), styleMask: .borderless, backing: .buffered, defer: false)
        view = MenuView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        super.init()
        view.owner = self
        view.title = files.count > 1 ? "\(files.count) files" : files[0].lastPathComponent
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.delegate = self
        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = 1
        }
        if formats.isEmpty {
            view.sub = "Can't convert ." + files[0].pathExtension + " files"
            view.needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self.dismiss() }
        }
    }

    func windowDidResignKey(_ notification: Notification) { if !busy { dismiss() } }

    func dismiss() {
        if closing { return }
        closing = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            window.animator().alphaValue = 0
        }, completionHandler: { self.close() })
    }

    func close() {
        view.stopSpinner()
        window.orderOut(nil)
        window.delegate = nil
    }

    func convert(_ chosen: Int?) {
        if busy { return }
        busy = true
        view.chosen = chosen
        view.titleColor = Ui.ink    // in case this is a retry after "Failed"
        view.toolTip = nil
        view.startSpinner()
        view.sub = "Converting"
        let kind = Conv.kind(files[0])
        let todo = files.filter { Conv.kind($0) == kind }
        let targets = chosen.map { [formats[$0]] } ?? formats
        let total = todo.count * targets.count
        DispatchQueue.global(qos: .userInitiated).async {
            var error: String? = nil, done = 0
            for file in todo {
                for target in targets {
                    let n = done + 1
                    DispatchQueue.main.async {
                        self.view.title = total > 1 ? "\(n) of \(total)" : "To " + target.label
                        if total > 1 { self.view.sub = "Making " + target.label }
                        self.view.needsDisplay = true
                    }
                    if let err = Conv.convert(file, target) { error = err }
                    done += 1
                }
            }
            let failure = error
            DispatchQueue.main.async { self.finished(failure, total) }
        }
    }

    func finished(_ error: String?, _ total: Int) {
        view.stopSpinner()
        if let error = error {
            view.title = "Failed"
            view.titleColor = Ui.red
            view.sub = error
            view.toolTip = error
            busy = false
            // if another app took focus meanwhile, a click outside can't close it: close it after a while
            if !window.isKeyWindow { DispatchQueue.main.asyncAfter(deadline: .now() + 6) { if !self.busy { self.dismiss() } } }
        } else {
            view.title = "✓ Saved"
            view.titleColor = Ui.green
            view.sub = total > 1 ? "\(total) files" : "Next to the original"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { self.dismiss() }
        }
        view.needsDisplay = true
    }
}

class MenuView: NSView {
    weak var owner: RadialMenu?
    var title = "", sub = "Convert to", titleColor = Ui.ink
    var hover: Int? = nil        // slice under the mouse
    var allHover = false         // pointing at the ring or the ALL tab
    var chosen: Int? = nil
    var spinAngle: CGFloat = 0
    var spinTimer: Timer?

    override var isFlipped: Bool { true }   // same coordinates as the Windows version: y goes down
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    let R = RadialMenu.R, pad = RadialMenu.pad
    var formats: [Fmt] { owner?.formats ?? [] }

    func P(_ r: CGFloat, _ deg: CGFloat) -> NSPoint {
        let a = deg * .pi / 180
        return NSPoint(x: pad + R + r * cos(a), y: pad + R + r * sin(a))
    }

    func angles(_ i: Int) -> (CGFloat, CGFloat) {
        let span = 360 / CGFloat(formats.count), gap: CGFloat = 2.5
        let a0 = -90 + CGFloat(i) * span + gap / 2
        return (a0, a0 + span - gap)
    }

    func sector(_ i: Int) -> NSBezierPath {
        let (a0, a1) = angles(i)
        let path = NSBezierPath()
        let steps = 32
        for s in 0...steps {
            let p = P(RadialMenu.rOut, a0 + (a1 - a0) * CGFloat(s) / CGFloat(steps))
            if s == 0 { path.move(to: p) } else { path.line(to: p) }
        }
        for s in (0...steps).reversed() { path.line(to: P(RadialMenu.rIn, a0 + (a1 - a0) * CGFloat(s) / CGFloat(steps))) }
        path.close()
        return path
    }

    var tabRect: NSRect {
        let w: CGFloat = 92
        return NSRect(x: pad + R - w / 2, y: pad + R + RadialMenu.ring - 13, width: w, height: 26)
    }

    func circle(_ r: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: pad + R - r, y: pad + R - r, width: 2 * r, height: 2 * r))
    }

    override func draw(_ dirtyRect: NSRect) {
        let busy = owner?.busy ?? false

        // disc
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 30
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
        shadow.set()
        NSColor(hex: 0xFFF6EF, alpha: 0.98).setFill()
        circle(162).fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(hex: 0xFFF6EF, alpha: 0.98), ending: NSColor(hex: 0xFFE2D0, alpha: 0.97))?.draw(in: circle(162), angle: 90)
        NSColor(white: 1, alpha: 0.56).setStroke()
        circle(162).stroke()

        // slices
        for i in formats.indices {
            let (a0, a1) = angles(i)
            let mid = (a0 + a1) / 2
            let on = (hover == i && !busy) || allHover || (busy && chosen == nil)
            let dim = busy && chosen != nil && chosen != i
            var shift = NSPoint.zero
            if hover == i && !busy && !allHover { shift = NSPoint(x: cos(mid * .pi / 180) * 7, y: sin(mid * .pi / 180) * 7) }
            NSGraphicsContext.saveGraphicsState()
            let t = NSAffineTransform()
            t.translateX(by: shift.x, yBy: shift.y)
            t.concat()
            let alpha: CGFloat = dim ? 0.35 : 1
            let fill = on ? (hover == i && !allHover ? Ui.hot : Ui.lit) : Ui.sliceFill
            fill.withAlphaComponent(fill.alphaComponent * alpha).setFill()
            sector(i).fill()
            let lp = P((RadialMenu.rIn + RadialMenu.rOut) / 2, mid)
            let ink = (on ? NSColor.white : Ui.ink).withAlphaComponent(alpha)
            let subInk = (on ? NSColor(white: 1, alpha: 0.9) : Ui.subInk).withAlphaComponent(alpha * (on ? 0.9 : 1))
            Ui.text(formats[i].label, size: 15, weight: .bold, color: ink, in: NSRect(x: lp.x - 42, y: lp.y - 17, width: 84, height: 20))
            Ui.text(formats[i].sub, size: 9.5, weight: .regular, color: subInk, in: NSRect(x: lp.x - 42, y: lp.y + 2, width: 84, height: 14))
            NSGraphicsContext.restoreGraphicsState()
        }

        // ALL ring and tab, when there is more than one format
        if formats.count > 1 {
            NSGraphicsContext.saveGraphicsState()
            if allHover {
                let glow = NSShadow()
                glow.shadowBlurRadius = 14
                glow.shadowColor = Ui.hot.withAlphaComponent(0.9)
                glow.set()
            }
            Ui.hot.withAlphaComponent(allHover ? 1 : 0.85).setStroke()
            let ring = circle(RadialMenu.ring)
            ring.lineWidth = 4
            ring.stroke()
            NSGraphicsContext.restoreGraphicsState()
            let tab = allHover ? tabRect.insetBy(dx: -5, dy: -1.5) : tabRect
            let pill = NSBezierPath(roundedRect: tab, xRadius: tab.height / 2, yRadius: tab.height / 2)
            NSGradient(starting: Ui.orange1, ending: Ui.orange2)?.draw(in: pill, angle: 0)
            NSColor(white: 1, alpha: 0.75).setStroke()
            pill.lineWidth = 1.5
            pill.stroke()
            Ui.text("ALL  ·  \(formats.count)", size: 12.5, weight: .bold, color: .white, in: NSRect(x: tab.minX, y: tab.minY + 5, width: tab.width, height: 18))
        }

        // center: file name, then progress and result
        NSGraphicsContext.saveGraphicsState()
        let cs = NSShadow()
        cs.shadowBlurRadius = 12
        cs.shadowOffset = NSSize(width: 0, height: -1)
        cs.shadowColor = NSColor(white: 0, alpha: 0.18)
        cs.set()
        NSColor(hex: 0xFFFBF8).setFill()
        circle(56).fill()
        NSGraphicsContext.restoreGraphicsState()
        if spinTimer != nil {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: pad + R, y: pad + R), radius: 52, startAngle: spinAngle, endAngle: spinAngle + 73)
            arc.lineWidth = 3
            arc.lineCapStyle = .round
            Ui.hot.setStroke()
            arc.stroke()
        }
        Ui.text(title, size: 12.5, weight: .semibold, color: titleColor, in: NSRect(x: pad + R - 46, y: pad + R - 22, width: 92, height: 18))
        Ui.text(sub, size: title == "Failed" ? 9 : 10.5, weight: .regular, color: Ui.subInk,
                in: NSRect(x: pad + R - 46, y: pad + R - 3, width: 92, height: 44), lineBreak: .byWordWrapping)
    }

    func startSpinner() {
        spinTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.spinAngle = (self.spinAngle + 6).truncatingRemainder(dividingBy: 360)
            self.needsDisplay = true
        }
        needsDisplay = true
    }

    func stopSpinner() {
        spinTimer?.invalidate()
        spinTimer = nil
        needsDisplay = true
    }

    // ---- mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }

    enum Spot: Equatable { case outside, slice(Int), all, center }

    func spot(_ p: NSPoint) -> Spot {
        let dx = p.x - pad - R, dy = p.y - pad - R, d = (dx * dx + dy * dy).squareRoot()
        if formats.count > 1 && (abs(d - RadialMenu.ring) <= 7 || tabRect.contains(p)) { return .all }
        if d <= 56 { return .center }
        if d >= RadialMenu.rIn && d <= RadialMenu.rOut && !formats.isEmpty {
            var deg = atan2(dy, dx) * 180 / .pi + 90     // 0 at the top, going clockwise
            if deg < 0 { deg += 360 }
            return .slice(min(formats.count - 1, Int(deg / (360 / CGFloat(formats.count)))))
        }
        return .outside
    }

    override func mouseMoved(with event: NSEvent) {
        if owner?.busy ?? true { return }
        let s = spot(convert(event.locationInWindow, from: nil))
        var newHover: Int? = nil
        if case .slice(let i) = s { newHover = i }
        let newAll = s == .all
        if newHover != hover || newAll != allHover {
            hover = newHover
            allHover = newAll
            needsDisplay = true
        }
        (s == .outside ? NSCursor.arrow : NSCursor.pointingHand).set()
    }

    override func mouseExited(with event: NSEvent) {
        if owner?.busy ?? true { return }
        hover = nil
        allHover = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let owner = owner else { return }
        switch spot(convert(event.locationInWindow, from: nil)) {
        case .slice(let i): owner.convert(i)
        case .all: owner.convert(nil)
        case .center, .outside: if !owner.busy { owner.dismiss() }
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, let owner = owner, !owner.busy { owner.dismiss() }   // Esc
    }
}

// ---------------------------------------------------------------- app

class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let support = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DropConvert")
    static let posFile = support.appendingPathComponent("position.txt")
    var bubble: NSWindow!

    // the bubble was dragged: remember the spot for next time
    func windowDidMove(_ notification: Notification) { App.savePosition(bubble.frame.origin) }

    static func savePosition(_ p: NSPoint) {
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? "\(Int(p.x)) \(Int(p.y))".write(to: posFile, atomically: true, encoding: .utf8)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // only one bubble at a time
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        let size: CGFloat = 96
        let area = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var origin = NSPoint(x: area.maxX - size - 40, y: area.minY + 120)
        if let s = try? String(contentsOf: App.posFile, encoding: .utf8) {
            let n = s.split(separator: " ").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let p = n.count == 2 ? NSPoint(x: n[0], y: n[1]) : origin
            if NSScreen.screens.contains(where: { $0.frame.contains(NSPoint(x: p.x + size / 2, y: p.y + size / 2)) }) { origin = p }
        }
        bubble = NSWindow(contentRect: NSRect(origin: origin, size: NSSize(width: size, height: size)),
                          styleMask: .borderless, backing: .buffered, defer: false)
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = false
        bubble.level = .floating
        bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        bubble.contentView = BubbleView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        bubble.delegate = self
        bubble.orderFrontRegardless()
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
