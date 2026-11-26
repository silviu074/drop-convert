// Drop Convert: a floating bubble. Drop files on it, pick a format from the round menu,
// and ffmpeg saves the converted copy next to the original.
// Build with build.cmd (uses the C# compiler that ships with Windows, C# 5).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Shapes;
using IOPath = System.IO.Path;

class Fmt
{
    public string Ext, Label, Sub, Args, Tool;
    public Fmt(string ext, string label, string sub, string args) : this(ext, label, sub, args, "ffmpeg") { }
    public Fmt(string ext, string label, string sub, string args, string tool) { Ext = ext; Label = label; Sub = sub; Args = args; Tool = tool; }
}

static class Conv
{
    static readonly string[] Video = { ".mp4", ".mov", ".mkv", ".avi", ".webm", ".m4v", ".wmv", ".flv", ".gif" };
    static readonly string[] Audio = { ".mp3", ".wav", ".flac", ".m4a", ".ogg", ".aac", ".opus", ".wma" };
    static readonly string[] Image = { ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff" };
    static readonly string[] Doc = { ".docx", ".doc", ".rtf", ".odt", ".txt" };

    const string Even = "-vf scale=trunc(iw/2)*2:trunc(ih/2)*2";
    const string Mp3 = "-vn -c:a libmp3lame -q:a 2";
    const string Wav = "-vn -c:a pcm_s16le";

    static readonly Fmt[] VideoOut = {
        new Fmt("mp4", "MP4", "Video", Even + " -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart"),
        new Fmt("mov", "MOV", "Video", Even + " -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k"),
        new Fmt("webm", "WEBM", "Web video", Even + " -c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1 -deadline good -cpu-used 4 -c:a libopus"),
        new Fmt("gif", "GIF", "Animation", "-vf \"fps=12,scale='min(480,iw)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse\" -loop 0"),
        new Fmt("mp3", "MP3", "Audio only", Mp3),
        new Fmt("wav", "WAV", "Audio only", Wav),
    };
    static readonly Fmt[] AudioOut = {
        new Fmt("mp3", "MP3", "Audio", Mp3),
        new Fmt("wav", "WAV", "Audio", Wav),
        new Fmt("flac", "FLAC", "Lossless", "-vn -c:a flac"),
        new Fmt("m4a", "M4A", "Audio", "-vn -c:a aac -b:a 192k"),
        new Fmt("ogg", "OGG", "Audio", "-vn -c:a libvorbis -q:a 5"),
    };
    static readonly Fmt[] ImageOut = {
        new Fmt("png", "PNG", "Image", "-frames:v 1 -update 1"),
        // JPG has no transparency: put see-through parts on white instead of black
        new Fmt("jpg", "JPG", "Photo", "-filter_complex \"[0]format=rgba,split[a][b];[a]drawbox=c=white:t=fill[w];[w][b]overlay,format=yuvj444p\" -frames:v 1 -update 1 -q:v 2"),
        new Fmt("webp", "WEBP", "Web image", "-frames:v 1 -update 1 -c:v libwebp -quality 90 -pix_fmt yuva420p"),
        new Fmt("bmp", "BMP", "Bitmap", "-frames:v 1 -update 1 -pix_fmt bgra"),
    };
    // Word documents go through the user's Word, hidden. Args = Word's WdSaveFormat number.
    static readonly Fmt[] DocOut = {
        new Fmt("pdf", "PDF", "Document", "17", "word"),
        new Fmt("docx", "DOCX", "Word", "16", "word"),
        new Fmt("odt", "ODT", "OpenDocument", "23", "word"),
        new Fmt("rtf", "RTF", "Rich text", "6", "word"),
        new Fmt("txt", "TXT", "Plain text", "2", "word"),
    };
    // PDF: Word reflows it into a document; Windows' own PDF renderer makes page images.
    static readonly Fmt[] PdfOut = {
        new Fmt("docx", "DOCX", "Word", "16", "word"),
        new Fmt("txt", "TXT", "Plain text", "2", "word"),
        new Fmt("jpg", "JPG", "Pages", "jpg", "pdfimg"),
        new Fmt("png", "PNG", "Pages", "png", "pdfimg"),
    };

    static string Ext(string file)
    {
        string e = IOPath.GetExtension(file).ToLowerInvariant();
        if (e == ".jpeg") return ".jpg";
        if (e == ".tif") return ".tiff";
        return e;
    }

    public static string Kind(string file)
    {
        string e = Ext(file);
        if (Video.Contains(e)) return "video";
        if (Audio.Contains(e)) return "audio";
        if (Image.Contains(e)) return "image";
        if (Doc.Contains(e)) return "doc";
        if (e == ".pdf") return "pdf";
        return null;
    }

    public static List<Fmt> Options(string file)
    {
        string e = Ext(file);
        string kind = Kind(file);
        Fmt[] all = kind == "video" ? VideoOut : kind == "audio" ? AudioOut : kind == "image" ? ImageOut
            : kind == "doc" ? DocOut : kind == "pdf" ? PdfOut : new Fmt[0];
        // a GIF has no sound, so no audio choices for it
        return all.Where(f => "." + f.Ext != e && !(e == ".gif" && f.Args.StartsWith("-vn"))).ToList();
    }

    static string OutPath(string file, string ext)
    {
        return OutPath(IOPath.GetDirectoryName(file), IOPath.GetFileNameWithoutExtension(file), ext);
    }

    static string OutPath(string dir, string name, string ext)
    {
        string path = IOPath.Combine(dir, name + "." + ext);
        for (int i = 2; System.IO.File.Exists(path); i++)
            path = IOPath.Combine(dir, name + " (" + i + ")." + ext);
        return path;
    }

    // Returns null on success, or the error message.
    public static string Run(string file, Fmt f)
    {
        if (f.Tool == "word") return RunWord(file, f);
        if (f.Tool == "pdfimg") return RunPdfImages(file, f.Ext);
        string output = OutPath(file, f.Ext);
        var psi = new ProcessStartInfo("ffmpeg",
            "-y -hide_banner -loglevel error -i \"" + file + "\" " + f.Args + " \"" + output + "\"");
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardError = true;
        try
        {
            using (var p = Process.Start(psi))
            {
                string err = p.StandardError.ReadToEnd();
                p.WaitForExit();
                if (p.ExitCode == 0) return null;
                if (System.IO.File.Exists(output)) System.IO.File.Delete(output);
                string[] lines = err.Trim().Split('\n');
                return lines.Length > 0 && lines[lines.Length - 1].Trim() != "" ? lines[lines.Length - 1].Trim() : "ffmpeg failed";
            }
        }
        catch (Exception ex) { return "Can't run ffmpeg: " + ex.Message; }
    }

    static string RunWord(string file, Fmt f)
    {
        string output = OutPath(file, f.Ext);
        string result = null;
        int pid = 0;
        // Word asks "convert this PDF?" in a hidden window, which would hang forever.
        // Turn that question off while we work, then put the user's setting back.
        const string opts = @"Software\Microsoft\Office\16.0\Word\Options";
        var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(opts);
        object oldWarn = key.GetValue("DisableConvertPdfWarning");
        key.SetValue("DisableConvertPdfWarning", 1, Microsoft.Win32.RegistryValueKind.DWord);
        // Word automation wants its own STA thread
        var t = new System.Threading.Thread(() =>
        {
            dynamic word = null;
            try
            {
                var before = Process.GetProcessesByName("WINWORD").Select(p => p.Id).ToList();
                word = Activator.CreateInstance(Type.GetTypeFromProgID("Word.Application"));
                pid = Process.GetProcessesByName("WINWORD").Select(p => p.Id).FirstOrDefault(id => !before.Contains(id));
                word.Visible = false;
                word.DisplayAlerts = 0;
                dynamic doc = word.Documents.Open(FileName: file, ConfirmConversions: false, ReadOnly: true, AddToRecentFiles: false);
                if (f.Ext == "txt") doc.SaveAs2(FileName: output, FileFormat: int.Parse(f.Args), Encoding: 65001);
                else doc.SaveAs2(FileName: output, FileFormat: int.Parse(f.Args));
                doc.Close(SaveChanges: 0);
            }
            catch (Exception ex) { result = "Word: " + ex.Message; }
            finally
            {
                if (word != null) try { word.Quit(SaveChanges: 0); } catch { }
            }
        });
        t.SetApartmentState(System.Threading.ApartmentState.STA);
        t.IsBackground = true;
        t.Start();
        if (!t.Join(TimeSpan.FromSeconds(120)))
        {
            // Word got stuck: close our hidden copy (never the user's own Word)
            if (pid != 0) try { Process.GetProcessById(pid).Kill(); } catch { }
            result = "Word took too long and was stopped";
        }
        if (oldWarn == null) key.DeleteValue("DisableConvertPdfWarning", false);
        else key.SetValue("DisableConvertPdfWarning", oldWarn);
        key.Close();
        if (result != null && System.IO.File.Exists(output)) System.IO.File.Delete(output);
        return result;
    }

    // One image per page: "name.png" for a single page, "name - page 3.png" otherwise.
    static string RunPdfImages(string file, string ext)
    {
        try
        {
            var sf = Wait(Windows.Storage.StorageFile.GetFileFromPathAsync(file));
            var pdf = Wait(Windows.Data.Pdf.PdfDocument.LoadFromFileAsync(sf));
            string dir = IOPath.GetDirectoryName(file), name = IOPath.GetFileNameWithoutExtension(file);
            for (uint i = 0; i < pdf.PageCount; i++)
            {
                using (var page = pdf.GetPage(i))
                using (var mem = new Windows.Storage.Streams.InMemoryRandomAccessStream())
                {
                    var opts = new Windows.Data.Pdf.PdfPageRenderOptions();
                    opts.DestinationWidth = 1700; // about 200 dpi for an A4 page, height follows
                    if (ext == "jpg") opts.BitmapEncoderId = Windows.Graphics.Imaging.BitmapEncoder.JpegEncoderId;
                    Wait(page.RenderToStreamAsync(mem, opts));
                    string output = OutPath(dir, pdf.PageCount == 1 ? name : name + " - page " + (i + 1), ext);
                    var reader = new Windows.Storage.Streams.DataReader(mem.GetInputStreamAt(0));
                    uint size = Wait(reader.LoadAsync((uint)mem.Size));
                    var bytes = new byte[size];
                    reader.ReadBytes(bytes);
                    System.IO.File.WriteAllBytes(output, bytes);
                }
            }
            return null;
        }
        catch (Exception ex) { return "PDF: " + ex.Message; }
    }

    // Windows' async calls without the SDK helpers: we're already on a worker thread, so just wait.
    static T Wait<T>(Windows.Foundation.IAsyncOperation<T> op)
    {
        Wait((Windows.Foundation.IAsyncInfo)op);
        return op.GetResults();
    }

    static void Wait(Windows.Foundation.IAsyncInfo op)
    {
        while (op.Status == Windows.Foundation.AsyncStatus.Started) System.Threading.Thread.Sleep(5);
        if (op.Status != Windows.Foundation.AsyncStatus.Completed) throw op.ErrorCode ?? new Exception("failed");
    }
}

static class Ui
{
    public static readonly FontFamily Font = new FontFamily("Segoe UI Variable Display, Segoe UI");
    public static Color C(string hex) { return (Color)ColorConverter.ConvertFromString(hex); }

    public static void Animate(IAnimatable target, DependencyProperty prop, double to, int ms, double delayMs, IEasingFunction ease)
    {
        var a = new DoubleAnimation(to, TimeSpan.FromMilliseconds(ms));
        a.BeginTime = TimeSpan.FromMilliseconds(delayMs);
        a.EasingFunction = ease;
        target.BeginAnimation(prop, a);
    }

    public static void AnimateColor(SolidColorBrush b, Color to, int ms)
    {
        b.BeginAnimation(SolidColorBrush.ColorProperty, new ColorAnimation(to, TimeSpan.FromMilliseconds(ms)));
    }

    public static IEasingFunction Back(double amp) { return new BackEase { Amplitude = amp, EasingMode = EasingMode.EaseOut }; }
}

class Bubble : Window
{
    // where the bubble was last dragged to, kept next to the exe
    static readonly string PosFile = IOPath.Combine(AppDomain.CurrentDomain.BaseDirectory, "position.txt");
    readonly ScaleTransform grow = new ScaleTransform(1, 1);
    RadialMenu menu;

    public Bubble()
    {
        Title = "Drop Convert";
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        Width = Height = 110;
        AllowDrop = true;
        Rect wa = SystemParameters.WorkArea;
        Left = wa.Right - Width - 8;
        Top = wa.Top + (wa.Height - Height) / 2;
        // put it back where it was last time, if that spot is still on a screen
        try
        {
            string[] p = System.IO.File.ReadAllText(PosFile).Split(',');
            double x = double.Parse(p[0], System.Globalization.CultureInfo.InvariantCulture);
            double y = double.Parse(p[1], System.Globalization.CultureInfo.InvariantCulture);
            if (x >= SystemParameters.VirtualScreenLeft && y >= SystemParameters.VirtualScreenTop
                && x + Width <= SystemParameters.VirtualScreenLeft + SystemParameters.VirtualScreenWidth
                && y + Height <= SystemParameters.VirtualScreenTop + SystemParameters.VirtualScreenHeight)
            {
                Left = x;
                Top = y;
            }
        }
        catch { }

        var pulse = new ScaleTransform(1, 1);
        var orb = new Grid { Width = 64, Height = 64, RenderTransformOrigin = new Point(0.5, 0.5) };
        var tg = new TransformGroup();
        tg.Children.Add(pulse);
        tg.Children.Add(grow);
        orb.RenderTransform = tg;
        orb.Children.Add(new Ellipse
        {
            Fill = new LinearGradientBrush(Ui.C("#FFFFB347"), Ui.C("#FFFF5E62"), 45),
            Effect = new DropShadowEffect { BlurRadius = 18, ShadowDepth = 3, Opacity = 0.35 },
        });
        orb.Children.Add(new TextBlock
        {
            Text = "⇄", Foreground = Brushes.White, FontSize = 28, FontWeight = FontWeights.Bold,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, -4, 0, 0), IsHitTestVisible = false,
        });
        orb.ToolTip = "Drop files here to convert";
        Content = orb;

        // slow breathing so it feels alive
        var breathe = new DoubleAnimation(1, 1.05, TimeSpan.FromSeconds(1.6))
        {
            AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever,
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut },
        };
        pulse.BeginAnimation(ScaleTransform.ScaleXProperty, breathe);
        pulse.BeginAnimation(ScaleTransform.ScaleYProperty, breathe);

        DragEnter += (s, e) => { if (e.Data.GetDataPresent(DataFormats.FileDrop)) Grow(1.3); };
        DragOver += (s, e) =>
        {
            e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
            e.Handled = true;
        };
        DragLeave += (s, e) => Grow(1);
        Drop += (s, e) =>
        {
            Grow(1);
            var files = e.Data.GetData(DataFormats.FileDrop) as string[];
            if (files != null && files.Length > 0) OpenMenu(files);
        };
        MouseLeftButtonDown += (s, e) =>
        {
            DragMove();
            try
            {
                System.IO.File.WriteAllText(PosFile, string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0},{1}", Left, Top));
            }
            catch { }
        };

        var label = new StackPanel { Orientation = Orientation.Horizontal };
        label.Children.Add(new TextBlock
        {
            Text = "", FontFamily = new FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets"), FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 1, 10, 0),
        });
        label.Children.Add(new TextBlock { Text = "Quit Drop Convert", VerticalAlignment = VerticalAlignment.Center });
        var quit = new MenuItem
        {
            Header = label, Template = ItemTemplate(), FontFamily = Ui.Font, FontSize = 13,
            FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Ui.C("#FF5A3A2E")),
        };
        quit.Click += (s, e) => Application.Current.Shutdown();
        ContextMenu = new ContextMenu { Template = MenuTemplate(), HasDropShadow = false };
        ContextMenu.Items.Add(quit);
    }

    // peach card with rounded corners, same colors as the round menu
    static ControlTemplate MenuTemplate()
    {
        var card = new FrameworkElementFactory(typeof(Border));
        card.SetValue(Border.BackgroundProperty, new LinearGradientBrush(Ui.C("#FFFFF6EF"), Ui.C("#FFFFE2D0"), 90));
        card.SetValue(Border.BorderBrushProperty, new SolidColorBrush(Ui.C("#90FFFFFF")));
        card.SetValue(Border.BorderThicknessProperty, new Thickness(1));
        card.SetValue(Border.CornerRadiusProperty, new CornerRadius(12));
        card.SetValue(Border.PaddingProperty, new Thickness(5));
        card.SetValue(Border.MarginProperty, new Thickness(12));
        card.SetValue(Border.EffectProperty, new DropShadowEffect { BlurRadius = 16, ShadowDepth = 3, Opacity = 0.3 });
        card.AppendChild(new FrameworkElementFactory(typeof(ItemsPresenter)));
        return new ControlTemplate(typeof(ContextMenu)) { VisualTree = card };
    }

    // menu row that turns orange with white text under the mouse
    static ControlTemplate ItemTemplate()
    {
        var row = new FrameworkElementFactory(typeof(Border), "row");
        row.SetValue(Border.BackgroundProperty, Brushes.Transparent);
        row.SetValue(Border.CornerRadiusProperty, new CornerRadius(8));
        row.SetValue(Border.PaddingProperty, new Thickness(14, 8, 18, 9));
        var content = new FrameworkElementFactory(typeof(ContentPresenter));
        content.SetValue(ContentPresenter.ContentSourceProperty, "Header");
        row.AppendChild(content);
        var t = new ControlTemplate(typeof(MenuItem)) { VisualTree = row };
        var hover = new Trigger { Property = MenuItem.IsHighlightedProperty, Value = true };
        hover.Setters.Add(new Setter(Border.BackgroundProperty, new LinearGradientBrush(Ui.C("#FFFFB347"), Ui.C("#FFFF5E62"), 0), "row"));
        hover.Setters.Add(new Setter(Control.ForegroundProperty, Brushes.White));
        t.Triggers.Add(hover);
        return t;
    }

    void Grow(double to)
    {
        Ui.Animate(grow, ScaleTransform.ScaleXProperty, to, 260, 0, Ui.Back(0.6));
        Ui.Animate(grow, ScaleTransform.ScaleYProperty, to, 260, 0, Ui.Back(0.6));
    }

    public void OpenMenu(string[] files)
    {
        if (menu != null) menu.Close();
        menu = new RadialMenu(files, new Point(Left + Width / 2, Top + Height / 2));
        menu.Closed += (s, e) => { if (menu == s) menu = null; };
        menu.Show();
        menu.Activate();
    }
}

class RadialMenu : Window
{
    const double D = 340, R = D / 2, RIn = 64, ROut = 154;

    readonly string[] files;
    readonly Canvas root = new Canvas { Width = D, Height = D, RenderTransformOrigin = new Point(0.5, 0.5) };
    readonly ScaleTransform rootScale = new ScaleTransform(0.6, 0.6);
    readonly List<Canvas> slices = new List<Canvas>();
    readonly List<Fmt> formats;
    // turns each slice's "all" highlight on or off (used by the ring)
    readonly List<Action<bool>> lighters = new List<Action<bool>>();
    readonly TextBlock title, sub;
    readonly Ellipse spinner;
    readonly RotateTransform spin = new RotateTransform(0, 52, 52);
    bool busy, closing;

    public RadialMenu(string[] files, Point anchor)
    {
        this.files = files;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        FontFamily = Ui.Font;
        // the window is only as big as the menu, so the rest of the screen stays clickable
        Background = Brushes.Transparent;
        Rect wa = SystemParameters.WorkArea;
        const double pad = 14; // room for the ring's glow and the ALL tab
        Width = D + 2 * pad;
        Height = D + 2 * pad + 10;
        Left = Math.Max(wa.Left + 8, Math.Min(wa.Right - Width - 8, anchor.X - R - pad));
        Top = Math.Max(wa.Top + 8, Math.Min(wa.Bottom - Height - 8, anchor.Y - R - pad));

        root.Margin = new Thickness(pad, pad, 0, 0);
        root.HorizontalAlignment = HorizontalAlignment.Left;
        root.VerticalAlignment = VerticalAlignment.Top;
        root.RenderTransform = rootScale;
        root.Opacity = 0;
        Content = root;

        var disc = new Ellipse
        {
            Width = 324, Height = 324,
            Fill = new LinearGradientBrush(Ui.C("#FAFFF6EF"), Ui.C("#F7FFE2D0"), 90),
            Stroke = new SolidColorBrush(Ui.C("#90FFFFFF")), StrokeThickness = 1,
            Effect = new DropShadowEffect { BlurRadius = 30, ShadowDepth = 6, Opacity = 0.3 },
        };
        Canvas.SetLeft(disc, R - 162);
        Canvas.SetTop(disc, R - 162);
        root.Children.Add(disc);

        List<Fmt> opts = Conv.Options(files[0]);
        formats = opts;
        for (int i = 0; i < opts.Count; i++) AddSlice(i, opts.Count, opts[i]);

        // center: file name, then progress and result
        var center = new Grid { Width = 112, Height = 112, Cursor = Cursors.Hand };
        center.Children.Add(new Ellipse
        {
            Fill = new SolidColorBrush(Ui.C("#FFFFFBF8")),
            Effect = new DropShadowEffect { BlurRadius = 12, ShadowDepth = 1, Opacity = 0.18 },
        });
        spinner = new Ellipse
        {
            Width = 104, Height = 104, StrokeThickness = 3, Visibility = Visibility.Hidden,
            Stroke = new LinearGradientBrush(Ui.C("#FFFFB347"), Ui.C("#FFFF5E62"), 45),
            StrokeDashArray = new DoubleCollection { 22, 87 }, StrokeDashCap = PenLineCap.Round,
            RenderTransform = spin,
        };
        center.Children.Add(spinner);
        var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Width = 92, IsHitTestVisible = false };
        title = new TextBlock
        {
            Text = files.Length > 1 ? files.Length + " files" : IOPath.GetFileName(files[0]),
            FontSize = 12.5, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Ui.C("#FF5A3A2E")),
            TextAlignment = TextAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis,
        };
        sub = new TextBlock
        {
            Text = "Convert to", FontSize = 10.5, Foreground = new SolidColorBrush(Ui.C("#FFA07A68")),
            TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap, MaxHeight = 56,
        };
        text.Children.Add(title);
        text.Children.Add(sub);
        center.Children.Add(text);
        center.MouseLeftButtonUp += (s, e) => { if (!busy) Dismiss(); };
        Canvas.SetLeft(center, R - 56);
        Canvas.SetTop(center, R - 56);
        root.Children.Add(center);

        // "all formats" button hanging under the circle, so it stands apart from the slices
        if (opts.Count > 1)
        {
            const double rr = 166; // ring radius, just outside the disc
            var glow = new DropShadowEffect { Color = Ui.C("#FFFF7A45"), ShadowDepth = 0, BlurRadius = 14, Opacity = 0 };
            var ring = new Ellipse
            {
                Width = 2 * rr, Height = 2 * rr, StrokeThickness = 4, Opacity = 0, IsHitTestVisible = false,
                Stroke = new LinearGradientBrush(Ui.C("#FFFFB347"), Ui.C("#FFFF5E62"), 45), Effect = glow,
            };
            // wider invisible ring so it's easy to point at
            var hit = new Ellipse
            {
                Width = 2 * rr, Height = 2 * rr, StrokeThickness = 14, Cursor = Cursors.Hand,
                Stroke = new SolidColorBrush(Color.FromArgb(1, 255, 255, 255)),
            };
            foreach (var el in new[] { ring, hit })
            {
                Canvas.SetLeft(el, R - rr);
                Canvas.SetTop(el, R - rr);
                root.Children.Add(el);
            }

            var tabText = new StackPanel { Orientation = Orientation.Horizontal };
            tabText.Children.Add(new TextBlock { Text = "ALL", FontSize = 12.5, FontWeight = FontWeights.Bold, Foreground = Brushes.White });
            tabText.Children.Add(new TextBlock
            {
                Text = "  ·  " + opts.Count, FontSize = 11.5, VerticalAlignment = VerticalAlignment.Center,
                Foreground = new SolidColorBrush(Ui.C("#E6FFFFFF")),
            });
            var tabScale = new ScaleTransform(1, 1);
            var tab = new Border
            {
                Child = tabText, CornerRadius = new CornerRadius(12), Padding = new Thickness(14, 3, 14, 4),
                Background = new LinearGradientBrush(Ui.C("#FFFFB347"), Ui.C("#FFFF5E62"), 0),
                BorderBrush = new SolidColorBrush(Ui.C("#C0FFFFFF")), BorderThickness = new Thickness(1.5),
                HorizontalAlignment = HorizontalAlignment.Center, Cursor = Cursors.Hand, Opacity = 0,
                RenderTransformOrigin = new Point(0.5, 0.5), RenderTransform = tabScale,
            };
            var tabRow = new Grid { Width = D };
            tabRow.Children.Add(tab);
            Canvas.SetTop(tabRow, R + rr - 13);
            root.Children.Add(tabRow);

            // pointing at the ring or tab: ring glows and every slice lights up together
            Action<bool> light = on =>
            {
                Ui.Animate(ring, OpacityProperty, on ? 1 : 0.85, 180, 0, null);
                Ui.Animate(glow, DropShadowEffect.OpacityProperty, on ? 0.9 : 0, 180, 0, null);
                Ui.Animate(tabScale, ScaleTransform.ScaleXProperty, on ? 1.1 : 1, 200, 0, Ui.Back(0.8));
                Ui.Animate(tabScale, ScaleTransform.ScaleYProperty, on ? 1.1 : 1, 200, 0, Ui.Back(0.8));
                foreach (var l in lighters) l(on);
            };
            foreach (UIElement el in new UIElement[] { hit, tab })
            {
                el.MouseEnter += (s, e) => { if (!busy) light(true); };
                el.MouseLeave += (s, e) => { if (!busy) light(false); };
                el.MouseLeftButtonUp += (s, e) => Convert(new Fmt("", "ALL", "", "", "all"), null);
            }
            double after = 60 + opts.Count * 35;
            Ui.Animate(ring, OpacityProperty, 0.85, 300, after, null);
            Ui.Animate(tab, OpacityProperty, 1, 240, after + 80, null);
        }

        Ui.Animate(root, OpacityProperty, 1, 180, 0, null);
        Ui.Animate(rootScale, ScaleTransform.ScaleXProperty, 1, 320, 0, Ui.Back(0.5));
        Ui.Animate(rootScale, ScaleTransform.ScaleYProperty, 1, 320, 0, Ui.Back(0.5));

        KeyDown += (s, e) => { if (e.Key == Key.Escape && !busy) Dismiss(); };
        Deactivated += (s, e) => { if (!busy) Dismiss(); };

        if (opts.Count == 0)
        {
            sub.Text = "Can't convert " + IOPath.GetExtension(files[0]) + " files";
            Task.Delay(1600).ContinueWith(t => Dispatcher.Invoke(new Action(Dismiss)));
        }
    }

    static Point P(double r, double deg)
    {
        double a = deg * Math.PI / 180;
        return new Point(R + r * Math.Cos(a), R + r * Math.Sin(a));
    }

    static Geometry Sector(double a0, double a1)
    {
        bool large = a1 - a0 > 180;
        var fig = new PathFigure { StartPoint = P(ROut, a0), IsClosed = true };
        fig.Segments.Add(new ArcSegment(P(ROut, a1), new Size(ROut, ROut), 0, large, SweepDirection.Clockwise, true));
        fig.Segments.Add(new LineSegment(P(RIn, a1), true));
        fig.Segments.Add(new ArcSegment(P(RIn, a0), new Size(RIn, RIn), 0, large, SweepDirection.Counterclockwise, true));
        return new PathGeometry(new[] { fig });
    }

    void AddSlice(int i, int n, Fmt fmt)
    {
        double span = 360.0 / n, gap = 2.5;
        double a0 = -90 + i * span + gap / 2, a1 = a0 + span - gap, mid = (a0 + a1) / 2;

        var layer = new Canvas { Width = D, Height = D, Opacity = 0 };
        var pop = new ScaleTransform(0.7, 0.7, R, R);
        var shift = new TranslateTransform();
        var tg = new TransformGroup();
        tg.Children.Add(pop);
        tg.Children.Add(shift);
        layer.RenderTransform = tg;

        var fill = new SolidColorBrush(Ui.C("#B8FFFFFF"));
        var ink = new SolidColorBrush(Ui.C("#FF5A3A2E"));
        var subInk = new SolidColorBrush(Ui.C("#FFA07A68"));
        var path = new Path { Data = Sector(a0, a1), Fill = fill, Cursor = Cursors.Hand };
        layer.Children.Add(path);

        var label = new StackPanel { Width = 84, IsHitTestVisible = false };
        label.Children.Add(new TextBlock { Text = fmt.Label, FontSize = 15, FontWeight = FontWeights.Bold, Foreground = ink, TextAlignment = TextAlignment.Center });
        label.Children.Add(new TextBlock { Text = fmt.Sub, FontSize = 9.5, Foreground = subInk, TextAlignment = TextAlignment.Center });
        Point lp = P((RIn + ROut) / 2, mid);
        Canvas.SetLeft(label, lp.X - 42);
        Canvas.SetTop(label, lp.Y - 17);
        layer.Children.Add(label);

        double dx = Math.Cos(mid * Math.PI / 180) * 7, dy = Math.Sin(mid * Math.PI / 180) * 7;
        path.MouseEnter += (s, e) =>
        {
            if (busy) return;
            Ui.AnimateColor(fill, Ui.C("#FFFF7A45"), 140);
            Ui.AnimateColor(ink, Colors.White, 140);
            Ui.AnimateColor(subInk, Ui.C("#E6FFFFFF"), 140);
            Ui.Animate(shift, TranslateTransform.XProperty, dx, 200, 0, Ui.Back(0.8));
            Ui.Animate(shift, TranslateTransform.YProperty, dy, 200, 0, Ui.Back(0.8));
        };
        path.MouseLeave += (s, e) =>
        {
            if (busy) return;
            Ui.AnimateColor(fill, Ui.C("#B8FFFFFF"), 180);
            Ui.AnimateColor(ink, Ui.C("#FF5A3A2E"), 180);
            Ui.AnimateColor(subInk, Ui.C("#FFA07A68"), 180);
            Ui.Animate(shift, TranslateTransform.XProperty, 0, 180, 0, null);
            Ui.Animate(shift, TranslateTransform.YProperty, 0, 180, 0, null);
        };
        path.MouseLeftButtonUp += (s, e) => Convert(fmt, layer);
        lighters.Add(on =>
        {
            Ui.AnimateColor(fill, on ? Ui.C("#FFFF9A62") : Ui.C("#B8FFFFFF"), 180);
            Ui.AnimateColor(ink, on ? Colors.White : Ui.C("#FF5A3A2E"), 180);
            Ui.AnimateColor(subInk, on ? Ui.C("#E6FFFFFF") : Ui.C("#FFA07A68"), 180);
        });

        double delay = 60 + i * 35;
        Ui.Animate(layer, OpacityProperty, 1, 220, delay, null);
        Ui.Animate(pop, ScaleTransform.ScaleXProperty, 1, 340, delay, Ui.Back(0.6));
        Ui.Animate(pop, ScaleTransform.ScaleYProperty, 1, 340, delay, Ui.Back(0.6));
        root.Children.Add(layer);
        slices.Add(layer);
    }

    async void Convert(Fmt fmt, Canvas chosen)
    {
        if (busy) return;
        busy = true;
        // a single format dims the other slices; ALL keeps everything lit
        if (chosen != null)
            foreach (var s in slices)
                if (s != chosen) Ui.Animate(s, OpacityProperty, 0.35, 200, 0, null);

        spinner.Visibility = Visibility.Visible;
        spin.BeginAnimation(RotateTransform.AngleProperty,
            new DoubleAnimation(0, 360, TimeSpan.FromSeconds(0.9)) { RepeatBehavior = RepeatBehavior.Forever });
        sub.Text = "Converting";

        string kind = Conv.Kind(files[0]);
        string[] todo = files.Where(f => Conv.Kind(f) == kind).ToArray();
        List<Fmt> targets = fmt.Tool == "all" ? formats : new List<Fmt> { fmt };
        int total = todo.Length * targets.Count, done = 0;
        string error = null;
        foreach (string file in todo)
            foreach (Fmt target in targets)
            {
                title.Text = total > 1 ? (done + 1) + " of " + total : "To " + fmt.Label;
                if (total > 1) sub.Text = "Making " + target.Label;
                string f = file;
                Fmt t = target;
                string err = await Task.Run(() => Conv.Run(f, t));
                if (err != null) error = err;
                done++;
            }

        spin.BeginAnimation(RotateTransform.AngleProperty, null);
        spinner.Visibility = Visibility.Hidden;
        if (error == null)
        {
            title.Text = "✓ Saved";
            title.Foreground = new SolidColorBrush(Ui.C("#FF2E9E5B"));
            sub.Text = total > 1 ? total + " files" : "Next to the original";
            await Task.Delay(900);
            Dismiss();
        }
        else
        {
            title.Text = "Failed";
            title.Foreground = new SolidColorBrush(Ui.C("#FFD9443A"));
            sub.Text = error;
            sub.FontSize = 9;
            root.ToolTip = error;
            busy = false;
        }
    }

    void Dismiss()
    {
        if (closing) return;
        closing = true;
        var fade = new DoubleAnimation(0, TimeSpan.FromMilliseconds(160));
        fade.Completed += (s, e) => Close();
        Ui.Animate(rootScale, ScaleTransform.ScaleXProperty, 0.85, 160, 0, null);
        Ui.Animate(rootScale, ScaleTransform.ScaleYProperty, 0.85, 160, 0, null);
        root.BeginAnimation(OpacityProperty, fade);
    }
}

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        // only one bubble: a second launch just exits
        bool first;
        var single = new System.Threading.Mutex(true, "DropConvert.SingleBubble", out first);
        if (!first) return;
        GC.KeepAlive(single);
        var app = new Application();
        var bubble = new Bubble();
        // files passed on the command line open the menu right away
        if (args.Length > 0) bubble.Loaded += (s, e) => bubble.OpenMenu(args);
        app.Run(bubble);
    }
}
