using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Text;
using System.Web.Script.Serialization;
using System.IO.Compression;
using System.Windows.Forms;

namespace GLWinToolNative
{
    public class AppItem
    {
        public string name { get; set; }
        public string id { get; set; }
        public string category { get; set; }
        public string description { get; set; }
        public string icon { get; set; }
        public bool selected { get; set; }
    }

    public class MainForm : Form
    {
        public const string AppVersion = "0.5.4";
        public const string UpdateManifestUrl = "https://raw.githubusercontent.com/mrmatias-of/assistente-glab/main/update.json";
        private readonly List<AppItem> catalog;
        private readonly FlowLayoutPanel cards = new FlowLayoutPanel();
        private readonly ComboBox categoryBox = new ComboBox();
        private readonly TextBox searchBox = new TextBox();
        private readonly TextBox logBox = new TextBox();
        private readonly Label statusLabel = new Label();

        public MainForm()
        {
            Text = "GL WinTool Nativo";
            Width = 1240;
            Height = 780;
            MinimumSize = new Size(1100, 700);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.FromArgb(232, 238, 246);
            Font = new Font("Segoe UI", 9F);
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);

            catalog = LoadCatalog();
            BuildLayout();
            RefreshCards();
            Log("GL WinTool nativo iniciado. Catalogo carregado: " + catalog.Count + " apps.");
        }

        private static List<AppItem> LoadCatalog()
        {
            var asm = Assembly.GetExecutingAssembly();
            using (var stream = asm.GetManifestResourceStream("config.apps.json"))
            using (var reader = new StreamReader(stream, Encoding.UTF8))
            {
                return new JavaScriptSerializer().Deserialize<List<AppItem>>(reader.ReadToEnd()) ?? new List<AppItem>();
            }
        }

        private void BuildLayout()
        {
            var root = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1, Padding = new Padding(10) };
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 112));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 120));
            Controls.Add(root);

            var banner = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(3, 7, 18), Padding = new Padding(18) };
            banner.Paint += (s, e) =>
            {
                using (var b = new System.Drawing.Drawing2D.LinearGradientBrush(banner.ClientRectangle, Color.FromArgb(3, 7, 18), Color.FromArgb(14, 116, 144), 15F))
                    e.Graphics.FillRectangle(b, banner.ClientRectangle);
            };
            root.Controls.Add(banner, 0, 0);

            var icon = new PictureBox { Width = 68, Height = 68, Left = 18, Top = 20, SizeMode = PictureBoxSizeMode.StretchImage, Image = Icon.ToBitmap() };
            banner.Controls.Add(icon);
            banner.Controls.Add(new Label { Text = "GL WinTool", ForeColor = Color.White, Font = new Font("Segoe UI", 28, FontStyle.Bold), AutoSize = true, Left = 102, Top = 20 });
            banner.Controls.Add(new Label { Text = "Central Windows para instalacao, ajustes, AppX e manutencao tecnica", ForeColor = Color.FromArgb(191, 219, 254), AutoSize = true, Left = 106, Top = 66 });
            banner.Controls.Add(new Label { Text = "Versao nativa " + AppVersion, ForeColor = Color.FromArgb(147, 197, 253), AutoSize = true, Left = 106, Top = 86 });
            statusLabel.Text = "Instalar - " + catalog.Count + " apps visiveis";
            statusLabel.ForeColor = Color.FromArgb(224, 242, 254);
            statusLabel.BackColor = Color.FromArgb(6, 18, 38);
            statusLabel.TextAlign = ContentAlignment.MiddleCenter;
            statusLabel.Width = 260;
            statusLabel.Height = 38;
            statusLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            statusLabel.Left = banner.Width - 290;
            statusLabel.Top = 34;
            statusLabel.Resize += (s, e) => statusLabel.Left = banner.Width - 290;
            banner.Resize += (s, e) => statusLabel.Left = banner.Width - 290;
            banner.Controls.Add(statusLabel);

            var tabs = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight };
            foreach (var text in new[] { "Instalar", "Ajustes", "Configurar", "Atualizar", "AppX", "Win11" })
                tabs.Controls.Add(new Button { Text = text, Width = 118, Height = 32 });
            searchBox.Width = 460;
            searchBox.Height = 30;
            searchBox.Margin = new Padding(18, 4, 0, 0);
            searchBox.TextChanged += (s, e) => RefreshCards();
            tabs.Controls.Add(searchBox);
            root.Controls.Add(tabs, 0, 1);

            var body = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2 };
            body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 240));
            body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            root.Controls.Add(body, 0, 2);

            var side = new Panel { Dock = DockStyle.Fill, BackColor = Color.White, Padding = new Padding(14) };
            body.Controls.Add(side, 0, 0);
            side.Controls.Add(new Label { Text = "Acoes", Font = new Font("Segoe UI", 15, FontStyle.Bold), Left = 12, Top = 14, AutoSize = true });
            AddSideButton(side, "+ Instalar selecionados", 52, () => RunWinget("install", SelectedApps()));
            AddSideButton(side, "Atualizar selecionados", 92, () => RunWinget("upgrade", SelectedApps()));
            AddSideButton(side, "Desinstalar selecionados", 132, () => RunWinget("uninstall", SelectedApps()));
            AddSideButton(side, "Limpar selecao", 184, () => { catalog.ForEach(a => a.selected = false); RefreshCards(); });
            categoryBox.Left = 12; categoryBox.Top = 238; categoryBox.Width = 202; categoryBox.DropDownStyle = ComboBoxStyle.DropDownList;
            var categories = new[] { "Todos", "Windows novo" }.Concat(catalog.Select(a => a.category).Where(c => !String.IsNullOrWhiteSpace(c))).Distinct().OrderBy(c => c).ToArray();
            categoryBox.Items.AddRange(categories.Cast<object>().ToArray());
            categoryBox.SelectedItem = "Windows novo";
            categoryBox.SelectedIndexChanged += (s, e) => RefreshCards();
            side.Controls.Add(new Label { Text = "Categoria", Left = 12, Top = 216, AutoSize = true, Font = new Font("Segoe UI", 9, FontStyle.Bold) });
            side.Controls.Add(categoryBox);

            cards.Dock = DockStyle.Fill;
            cards.AutoScroll = true;
            cards.Padding = new Padding(8);
            body.Controls.Add(cards, 1, 0);

            logBox.Dock = DockStyle.Fill;
            logBox.Multiline = true;
            logBox.ReadOnly = true;
            logBox.BackColor = Color.FromArgb(15, 23, 42);
            logBox.ForeColor = Color.White;
            logBox.Font = new Font("Consolas", 9);
            root.Controls.Add(logBox, 0, 3);
        }

        private void AddSideButton(Control parent, string text, int top, Action action)
        {
            var b = new Button { Text = text, Left = 12, Top = top, Width = 202, Height = 32 };
            b.Click += (s, e) => action();
            parent.Controls.Add(b);
        }

        private IEnumerable<AppItem> SelectedApps() { return catalog.Where(a => a.selected); }

        private void RefreshCards()
        {
            cards.SuspendLayout();
            cards.Controls.Clear();
            var q = searchBox.Text.Trim();
            var cat = categoryBox.SelectedItem == null ? "Todos" : categoryBox.SelectedItem.ToString();
            var apps = catalog.Where(a => (cat == "Todos" || a.category == cat) &&
                (q.Length == 0 || (a.name + " " + a.id + " " + a.description + " " + a.category).IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0))
                .OrderBy(a => a.category).ThenBy(a => a.name).ToList();

            if (cat == "Windows novo" && apps.Count == 0)
            {
                cards.Controls.Add(MakeInfoCard("Windows novo", "Categoria reservada para apps pos-formatacao."));
            }
            else
            {
                foreach (var app in apps) cards.Controls.Add(MakeAppCard(app));
            }
            statusLabel.Text = "Instalar - " + apps.Count + " apps visiveis";
            cards.ResumeLayout();
        }

        private Control MakeInfoCard(string title, string body)
        {
            var p = new Panel { Width = 340, Height = 92, BackColor = Color.White, Margin = new Padding(7) };
            p.Controls.Add(new Label { Text = title, Left = 14, Top = 14, AutoSize = true, Font = new Font("Segoe UI", 10, FontStyle.Bold) });
            p.Controls.Add(new Label { Text = body, Left = 14, Top = 40, Width = 300, Height = 40, ForeColor = Color.FromArgb(51, 65, 85) });
            return p;
        }

        private Control MakeAppCard(AppItem app)
        {
            var p = new Panel { Width = 292, Height = 86, BackColor = Color.White, Margin = new Padding(7) };
            p.Controls.Add(new Label { Text = String.IsNullOrWhiteSpace(app.icon) ? "APP" : app.icon, Left = 12, Top = 20, Width = 46, Height = 34, TextAlign = ContentAlignment.MiddleCenter, BackColor = Color.FromArgb(224, 242, 254), Font = new Font("Segoe UI", 9, FontStyle.Bold) });
            p.Controls.Add(new Label { Text = app.name, Left = 70, Top = 12, Width = 175, Height = 20, Font = new Font("Segoe UI", 9, FontStyle.Bold) });
            p.Controls.Add(new Label { Text = app.description, Left = 70, Top = 34, Width = 175, Height = 20, ForeColor = Color.FromArgb(51, 65, 85) });
            p.Controls.Add(new Label { Text = app.id, Left = 70, Top = 55, Width = 175, Height = 18, ForeColor = Color.FromArgb(71, 85, 105), Font = new Font("Segoe UI", 7) });
            var cb = new CheckBox { Left = 258, Top = 32, Checked = app.selected };
            cb.CheckedChanged += (s, e) => app.selected = cb.Checked;
            p.Controls.Add(cb);
            return p;
        }

        private void RunWinget(string action, IEnumerable<AppItem> apps)
        {
            var list = apps.ToList();
            if (list.Count == 0) { Log("Nenhum app selecionado."); return; }
            foreach (var app in list)
            {
                var args = action + " --id \"" + app.id + "\" --exact --accept-source-agreements --disable-interactivity";
                if (action == "install" || action == "upgrade") args += " --accept-package-agreements --silent";
                if (action == "uninstall") args += " --silent";
                Log("> winget " + args);
                var psi = new ProcessStartInfo("winget", args) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
                using (var p = Process.Start(psi))
                {
                    Log(p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd());
                }
            }
        }

        private void Log(string text)
        {
            logBox.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + text + Environment.NewLine);
        }
    }

    public class UpdateManifest
    {
        public string version { get; set; }
        public string zipUrl { get; set; }
        public string exeUrl { get; set; }
        public string notes { get; set; }
    }

    public class UpdateForm : Form
    {
        private readonly Label status = new Label();
        private readonly Button updateButton = new Button();
        private readonly ProgressBar progress = new ProgressBar();
        private UpdateManifest manifest;

        public bool ContinueToApp { get; private set; }

        public UpdateForm()
        {
            Text = "GL WinTool";
            Width = 560;
            Height = 360;
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            BackColor = Color.FromArgb(3, 7, 18);
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);

            var icon = new PictureBox { Width = 82, Height = 82, Left = 239, Top = 34, SizeMode = PictureBoxSizeMode.StretchImage, Image = Icon.ToBitmap() };
            Controls.Add(icon);
            Controls.Add(new Label { Text = "GL WinTool", ForeColor = Color.White, Font = new Font("Segoe UI", 24, FontStyle.Bold), AutoSize = true, Left = 198, Top = 124 });
            status.Text = "Buscando atualizacao...";
            status.ForeColor = Color.FromArgb(147, 197, 253);
            status.TextAlign = ContentAlignment.MiddleCenter;
            status.Left = 36;
            status.Top = 172;
            status.Width = 488;
            status.Height = 42;
            Controls.Add(status);

            progress.Left = 42;
            progress.Top = 226;
            progress.Width = 460;
            progress.Height = 8;
            progress.Style = ProgressBarStyle.Marquee;
            Controls.Add(progress);

            updateButton.Text = "Atualizar";
            updateButton.Left = 182;
            updateButton.Top = 254;
            updateButton.Width = 190;
            updateButton.Height = 38;
            updateButton.Visible = false;
            updateButton.Click += (s, e) => ApplyUpdate();
            Controls.Add(updateButton);

            Shown += (s, e) => CheckUpdate();
        }

        private void CheckUpdate()
        {
            try
            {
                using (var web = new WebClient())
                {
                    var json = web.DownloadString(MainForm.UpdateManifestUrl + "?cache=" + DateTime.UtcNow.Ticks);
                    manifest = new JavaScriptSerializer().Deserialize<UpdateManifest>(json);
                }
                progress.Style = ProgressBarStyle.Continuous;
                if (manifest != null && !String.Equals(manifest.version, MainForm.AppVersion, StringComparison.OrdinalIgnoreCase))
                {
                    status.Text = "Atualizacao disponivel: " + manifest.version + ". Atualize para continuar.";
                    updateButton.Visible = true;
                    return;
                }
                status.Text = "Sem atualizacao disponivel.";
                var timer = new Timer { Interval = 1000 };
                timer.Tick += (s, e) => { timer.Stop(); ContinueToApp = true; Close(); };
                timer.Start();
            }
            catch
            {
                status.Text = "Nao foi possivel checar atualizacao. Iniciando offline.";
                var timer = new Timer { Interval = 1200 };
                timer.Tick += (s, e) => { timer.Stop(); ContinueToApp = true; Close(); };
                timer.Start();
            }
        }

        private void ApplyUpdate()
        {
            if (manifest == null || String.IsNullOrWhiteSpace(manifest.zipUrl)) return;
            updateButton.Enabled = false;
            status.Text = "Baixando atualizacao...";
            progress.Style = ProgressBarStyle.Marquee;
            try
            {
                var tempRoot = Path.Combine(Path.GetTempPath(), "GL-WinTool-native-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(tempRoot);
                var zip = Path.Combine(tempRoot, "GL-WinTool-Native.zip");
                using (var web = new WebClient()) web.DownloadFile(manifest.zipUrl, zip);
                ZipFile.ExtractToDirectory(zip, tempRoot);
                var newExe = Directory.GetFiles(tempRoot, "GL-WinTool.exe", SearchOption.AllDirectories).FirstOrDefault();
                if (String.IsNullOrWhiteSpace(newExe)) throw new Exception("Executavel nativo nao encontrado no pacote.");

                var currentExe = Application.ExecutablePath;
                var updater = Path.Combine(tempRoot, "Apply-GL-WinTool-Native-Update.cmd");
                File.WriteAllText(updater,
                    "@echo off\r\n" +
                    "timeout /t 1 /nobreak >nul\r\n" +
                    ":wait\r\n" +
                    "copy /y \"" + newExe + "\" \"" + currentExe + "\" >nul 2>nul\r\n" +
                    "if errorlevel 1 (timeout /t 1 /nobreak >nul & goto wait)\r\n" +
                    "start \"\" \"" + currentExe + "\"\r\n",
                    Encoding.ASCII);
                Process.Start(new ProcessStartInfo(updater) { CreateNoWindow = true, UseShellExecute = false, WindowStyle = ProcessWindowStyle.Hidden });
                Application.Exit();
            }
            catch (Exception ex)
            {
                progress.Style = ProgressBarStyle.Continuous;
                status.Text = "Falha ao atualizar: " + ex.Message;
                updateButton.Enabled = true;
            }
        }
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (var update = new UpdateForm())
            {
                update.ShowDialog();
                if (!update.ContinueToApp) return;
            }
            Application.Run(new MainForm());
        }
    }
}



