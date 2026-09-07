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
        public const string AppVersion = "0.5.15";
        public const string UpdateManifestUrl = "https://raw.githubusercontent.com/mrmatias-of/GLWinTool/main/update.json";
        private const string DefaultAdminPassword = "glabadmin";
        private readonly List<AppItem> catalog;
        private readonly FlowLayoutPanel cards = new FlowLayoutPanel();
        private readonly ComboBox categoryBox = new ComboBox();
        private readonly TextBox searchBox = new TextBox();
        private readonly TextBox logBox = new TextBox();
        private readonly Label statusLabel = new Label();
        private readonly Label adminStateLabel = new Label();
        private readonly TextBox adminPasswordBox = new TextBox();
        private readonly Image headerBanner = LoadEmbeddedImage("assets.app-header-banner.png");
        private bool adminUnlocked;

        public MainForm()
        {
            Text = "GL WinTool " + AppVersion;
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

        public static Image LoadEmbeddedImage(string name)
        {
            var asm = Assembly.GetExecutingAssembly();
            using (var stream = asm.GetManifestResourceStream(name))
            {
                if (stream == null) return null;
                return Image.FromStream(stream);
            }
        }

        private void BuildLayout()
        {
            var root = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1, Padding = new Padding(10) };
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 156));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 120));
            Controls.Add(root);

            var banner = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(3, 7, 18), Padding = new Padding(18), Margin = new Padding(0, 0, 0, 8) };
            banner.Paint += (s, e) =>
            {
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                e.Graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                e.Graphics.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                if (headerBanner != null)
                {
                    e.Graphics.DrawImage(headerBanner, banner.ClientRectangle);
                    using (var leftShade = new System.Drawing.Drawing2D.LinearGradientBrush(new Rectangle(0, 0, 470, banner.Height), Color.FromArgb(245, 3, 7, 18), Color.FromArgb(120, 3, 7, 18), 0F))
                        e.Graphics.FillRectangle(leftShade, new Rectangle(0, 0, 470, banner.Height));
                    using (var glow = new Pen(Color.FromArgb(120, 34, 211, 238), 2F))
                        e.Graphics.DrawLine(glow, 0, banner.Height - 2, banner.Width, banner.Height - 2);
                }
                else
                {
                    using (var b = new System.Drawing.Drawing2D.LinearGradientBrush(banner.ClientRectangle, Color.FromArgb(3, 7, 18), Color.FromArgb(14, 116, 144), 15F))
                        e.Graphics.FillRectangle(b, banner.ClientRectangle);
                }
            };
            root.Controls.Add(banner, 0, 0);

            var icon = new PictureBox { Width = 86, Height = 86, Left = 22, Top = 34, SizeMode = PictureBoxSizeMode.StretchImage, Image = Icon.ToBitmap(), BackColor = Color.Transparent };
            banner.Controls.Add(icon);
            banner.Controls.Add(new Label { Text = "GL WinTool", ForeColor = Color.White, Font = new Font("Segoe UI", 30, FontStyle.Bold), AutoSize = true, Left = 126, Top = 34, BackColor = Color.Transparent });
            banner.Controls.Add(new Label { Text = "Instalacao, ajustes, AppX e manutencao Windows", ForeColor = Color.FromArgb(219, 234, 254), Font = new Font("Segoe UI", 10, FontStyle.Regular), AutoSize = true, Left = 130, Top = 82, BackColor = Color.Transparent });
            banner.Controls.Add(new Label { Text = "Versao " + AppVersion + " - pt-BR - WinGet e backups preventivos", ForeColor = Color.FromArgb(125, 211, 252), Font = new Font("Segoe UI", 9, FontStyle.Regular), AutoSize = true, Left = 130, Top = 106, BackColor = Color.Transparent });
            statusLabel.Text = "Instalar - " + catalog.Count + " apps visiveis";
            statusLabel.ForeColor = Color.FromArgb(224, 242, 254);
            statusLabel.BackColor = Color.FromArgb(6, 18, 38);
            statusLabel.TextAlign = ContentAlignment.MiddleCenter;
            statusLabel.Width = 260;
            statusLabel.Height = 38;
            statusLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            statusLabel.Left = banner.Width - 300;
            statusLabel.Top = 18;
            statusLabel.Resize += (s, e) => statusLabel.Left = banner.Width - 300;
            banner.Resize += (s, e) => statusLabel.Left = banner.Width - 300;
            banner.Controls.Add(statusLabel);

            var tabs = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight, Padding = new Padding(0, 2, 0, 0) };
            foreach (var text in new[] { "Instalar", "Ajustes", "Configurar", "Atualizar", "AppX", "Win11" })
                tabs.Controls.Add(MakeNavButton(text));
            searchBox.Width = 460;
            searchBox.Height = 30;
            searchBox.Margin = new Padding(18, 4, 0, 0);
            searchBox.ForeColor = Color.FromArgb(15, 23, 42);
            searchBox.Font = new Font("Segoe UI", 10);
            searchBox.TextChanged += (s, e) => RefreshCards();
            tabs.Controls.Add(searchBox);
            root.Controls.Add(tabs, 0, 1);

            var body = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2 };
            body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 240));
            body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            root.Controls.Add(body, 0, 2);

            var side = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(248, 250, 252), Padding = new Padding(14), Margin = new Padding(0, 0, 10, 0) };
            side.Paint += (s, e) => DrawRoundedSurface(e.Graphics, side.ClientRectangle, Color.FromArgb(248, 250, 252), Color.FromArgb(203, 213, 225), 18);
            body.Controls.Add(side, 0, 0);
            side.Controls.Add(new Label { Text = "Central de acoes", Font = new Font("Segoe UI", 14, FontStyle.Bold), Left = 18, Top = 18, AutoSize = true, ForeColor = Color.FromArgb(15, 23, 42), BackColor = Color.Transparent });
            side.Controls.Add(new Label { Text = "Escolha os apps e execute com seguranca.", Left = 19, Top = 47, Width = 190, Height = 34, ForeColor = Color.FromArgb(71, 85, 105), BackColor = Color.Transparent });
            AddSideButton(side, "Instalar selecionados", 92, true, () => RunWinget("install", SelectedApps()));
            AddSideButton(side, "Atualizar selecionados", 134, false, () => RunWinget("upgrade", SelectedApps()));
            AddSideButton(side, "Desinstalar selecionados", 176, false, () => RunWinget("uninstall", SelectedApps()));
            AddSideButton(side, "Limpar selecao", 230, false, () => { catalog.ForEach(a => a.selected = false); RefreshCards(); });
            categoryBox.Left = 18; categoryBox.Top = 304; categoryBox.Width = 194; categoryBox.DropDownStyle = ComboBoxStyle.DropDownList;
            categoryBox.Font = new Font("Segoe UI", 9);
            var categories = new[] { "Todos", "Windows novo" }.Concat(catalog.Select(a => a.category).Where(c => !String.IsNullOrWhiteSpace(c))).Distinct().OrderBy(c => c).ToArray();
            categoryBox.Items.AddRange(categories.Cast<object>().ToArray());
            categoryBox.SelectedItem = "Windows novo";
            categoryBox.SelectedIndexChanged += (s, e) => RefreshCards();
            side.Controls.Add(new Label { Text = "Categoria", Left = 18, Top = 280, AutoSize = true, Font = new Font("Segoe UI", 9, FontStyle.Bold), ForeColor = Color.FromArgb(30, 41, 59), BackColor = Color.Transparent });
            side.Controls.Add(categoryBox);

            side.Controls.Add(new Label { Text = "Area admin", Left = 18, Top = 354, AutoSize = true, Font = new Font("Segoe UI", 9, FontStyle.Bold), ForeColor = Color.FromArgb(30, 41, 59), BackColor = Color.Transparent });
            adminPasswordBox.Left = 18;
            adminPasswordBox.Top = 378;
            adminPasswordBox.Width = 194;
            adminPasswordBox.Height = 26;
            adminPasswordBox.UseSystemPasswordChar = true;
            adminPasswordBox.Font = new Font("Segoe UI", 9);
            adminPasswordBox.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) UnlockAdmin(); };
            side.Controls.Add(adminPasswordBox);
            AddSideButton(side, "Desbloquear admin", 412, false, UnlockAdmin);
            AddSideButton(side, "Config admin", 454, false, ShowAdminPanel);
            adminStateLabel.Text = "Admin bloqueado";
            adminStateLabel.Left = 18;
            adminStateLabel.Top = 496;
            adminStateLabel.Width = 194;
            adminStateLabel.Height = 38;
            adminStateLabel.ForeColor = Color.FromArgb(185, 28, 28);
            adminStateLabel.BackColor = Color.Transparent;
            side.Controls.Add(adminStateLabel);

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

        private Button MakeNavButton(string text)
        {
            var b = new Button { Text = text, Width = 118, Height = 32, Margin = new Padding(0, 4, 8, 0), FlatStyle = FlatStyle.Flat, BackColor = text == "Instalar" ? Color.FromArgb(2, 44, 64) : Color.White, ForeColor = text == "Instalar" ? Color.White : Color.FromArgb(15, 23, 42), Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            b.FlatAppearance.BorderColor = Color.FromArgb(186, 199, 218);
            b.FlatAppearance.MouseOverBackColor = Color.FromArgb(224, 242, 254);
            b.FlatAppearance.MouseDownBackColor = Color.FromArgb(186, 230, 253);
            if (text == "Configurar") b.Click += (s, e) => ShowAdminPanel();
            return b;
        }

        private void AddSideButton(Control parent, string text, int top, bool primary, Action action)
        {
            var b = new Button { Text = text, Left = 18, Top = top, Width = 194, Height = 34, FlatStyle = FlatStyle.Flat, BackColor = primary ? Color.FromArgb(2, 132, 199) : Color.White, ForeColor = primary ? Color.White : Color.FromArgb(15, 23, 42), Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            b.FlatAppearance.BorderColor = primary ? Color.FromArgb(14, 165, 233) : Color.FromArgb(203, 213, 225);
            b.FlatAppearance.MouseOverBackColor = primary ? Color.FromArgb(3, 105, 161) : Color.FromArgb(239, 246, 255);
            b.Click += (s, e) => action();
            parent.Controls.Add(b);
        }

        private static void DrawRoundedSurface(Graphics graphics, Rectangle bounds, Color fill, Color border, int radius)
        {
            if (bounds.Width <= 1 || bounds.Height <= 1) return;
            bounds = new Rectangle(bounds.X, bounds.Y, bounds.Width - 1, bounds.Height - 1);
            using (var path = RoundedRect(bounds, radius))
            using (var brush = new SolidBrush(fill))
            using (var pen = new Pen(border))
            {
                graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                graphics.FillPath(brush, path);
                graphics.DrawPath(pen, path);
            }
        }

        private static System.Drawing.Drawing2D.GraphicsPath RoundedRect(Rectangle bounds, int radius)
        {
            int d = radius * 2;
            var path = new System.Drawing.Drawing2D.GraphicsPath();
            path.AddArc(bounds.Left, bounds.Top, d, d, 180, 90);
            path.AddArc(bounds.Right - d, bounds.Top, d, d, 270, 90);
            path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
            path.AddArc(bounds.Left, bounds.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        private IEnumerable<AppItem> SelectedApps() { return catalog.Where(a => a.selected); }

        private void UnlockAdmin()
        {
            if (adminPasswordBox.Text == DefaultAdminPassword)
            {
                adminUnlocked = true;
                adminPasswordBox.Clear();
                adminStateLabel.Text = "Admin liberado nesta sessao";
                adminStateLabel.ForeColor = Color.FromArgb(4, 120, 87);
                Log("Modo administrador desbloqueado.");
                ShowAdminPanel();
                return;
            }

            adminUnlocked = false;
            adminStateLabel.Text = "Senha invalida";
            adminStateLabel.ForeColor = Color.FromArgb(185, 28, 28);
            Log("Tentativa de acesso admin recusada.");
        }

        private void ShowAdminPanel()
        {
            cards.SuspendLayout();
            cards.Controls.Clear();
            if (!adminUnlocked)
            {
                cards.Controls.Add(MakeInfoCard("Configuracoes admin", "Area protegida por senha.", "Digite a senha no menu lateral para liberar opcoes administrativas do GL WinTool."));
                statusLabel.Text = "Configurar - admin bloqueado";
                cards.ResumeLayout();
                return;
            }

            cards.Controls.Add(MakeAdminCard("Atualizacoes", "Consultar manifesto remoto e validar versao publicada.", "Verificar agora", () => CheckAdminUpdates()));
            cards.Controls.Add(MakeAdminCard("Catalogo", "Resumo do catalogo embutido no executavel atual.", "Ver resumo", () => ShowCatalogSummary()));
            cards.Controls.Add(MakeAdminCard("Ambiente", "Abrir a pasta local onde o GL WinTool esta rodando.", "Abrir pasta", () => OpenAppFolder()));
            cards.Controls.Add(MakeAdminCard("Logs", "Limpar somente a tela de registro desta sessao.", "Limpar log", () => logBox.Clear()));
            statusLabel.Text = "Configurar - admin liberado";
            cards.ResumeLayout();
        }

        private Control MakeAdminCard(string title, string body, string buttonText, Action action)
        {
            var p = new Panel { Width = 430, Height = 142, BackColor = Color.Transparent, Margin = new Padding(10) };
            p.Paint += (s, e) => DrawRoundedSurface(e.Graphics, p.ClientRectangle, Color.White, Color.FromArgb(14, 165, 233), 18);
            p.Controls.Add(new Label { Text = title, Left = 22, Top = 18, AutoSize = true, Font = new Font("Segoe UI", 13, FontStyle.Bold), ForeColor = Color.FromArgb(15, 23, 42), BackColor = Color.Transparent });
            p.Controls.Add(new Label { Text = body, Left = 24, Top = 48, Width = 374, Height = 38, ForeColor = Color.FromArgb(71, 85, 105), BackColor = Color.Transparent });
            var b = new Button { Text = buttonText, Left = 24, Top = 94, Width = 160, Height = 32, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(2, 132, 199), ForeColor = Color.White, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            b.FlatAppearance.BorderColor = Color.FromArgb(125, 211, 252);
            b.Click += (s, e) => action();
            p.Controls.Add(b);
            return p;
        }

        private void CheckAdminUpdates()
        {
            try
            {
                using (var web = new WebClient())
                {
                    var json = web.DownloadString(UpdateManifestUrl + "?cache=" + DateTime.UtcNow.Ticks);
                    var manifest = new JavaScriptSerializer().Deserialize<UpdateManifest>(json);
                    Log("Versao local: " + AppVersion);
                    Log("Versao publicada: " + (manifest == null ? "nao lida" : manifest.version));
                    Log(manifest != null && manifest.version != AppVersion ? "Atualizacao disponivel." : "Aplicativo atualizado.");
                }
            }
            catch (Exception ex) { Log("Falha ao consultar atualizacao: " + ex.Message); }
        }

        private void ShowCatalogSummary()
        {
            var categories = catalog.GroupBy(a => a.category ?? "Sem categoria").OrderByDescending(g => g.Count()).Take(8);
            Log("Catalogo atual: " + catalog.Count + " apps.");
            foreach (var group in categories) Log(group.Key + ": " + group.Count() + " apps.");
        }

        private void OpenAppFolder()
        {
            try { Process.Start("explorer.exe", Path.GetDirectoryName(Application.ExecutablePath)); }
            catch (Exception ex) { Log("Falha ao abrir pasta: " + ex.Message); }
        }

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
                cards.Controls.Add(MakeInfoCard("Windows novo", "Sua lista de pos-formatacao vai aparecer aqui.", "Use esta categoria para montar o pacote padrao das maquinas novas da G-LAB."));
            }
            else
            {
                foreach (var app in apps) cards.Controls.Add(MakeAppCard(app));
            }
            statusLabel.Text = "Instalar - " + apps.Count + " apps visiveis";
            cards.ResumeLayout();
        }

        private Control MakeInfoCard(string title, string body, string detail)
        {
            var p = new Panel { Width = 560, Height = 150, BackColor = Color.Transparent, Margin = new Padding(10) };
            p.Paint += (s, e) => DrawRoundedSurface(e.Graphics, p.ClientRectangle, Color.White, Color.FromArgb(191, 219, 254), 18);
            p.Controls.Add(new Label { Text = title, Left = 22, Top = 22, AutoSize = true, Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = Color.FromArgb(15, 23, 42), BackColor = Color.Transparent });
            p.Controls.Add(new Label { Text = body, Left = 24, Top = 66, Width = 500, Height = 24, ForeColor = Color.FromArgb(37, 99, 235), Font = new Font("Segoe UI", 10, FontStyle.Bold), BackColor = Color.Transparent });
            p.Controls.Add(new Label { Text = detail, Left = 24, Top = 96, Width = 500, Height = 34, ForeColor = Color.FromArgb(71, 85, 105), BackColor = Color.Transparent });
            return p;
        }

        private Control MakeAppCard(AppItem app)
        {
            var p = new Panel { Width = 300, Height = 104, BackColor = Color.Transparent, Margin = new Padding(8) };
            p.Paint += (s, e) => DrawRoundedSurface(e.Graphics, p.ClientRectangle, Color.White, app.selected ? Color.FromArgb(14, 165, 233) : Color.FromArgb(203, 213, 225), 16);
            p.Controls.Add(new Label { Text = String.IsNullOrWhiteSpace(app.icon) ? "APP" : app.icon, Left = 14, Top = 24, Width = 52, Height = 52, TextAlign = ContentAlignment.MiddleCenter, BackColor = Color.FromArgb(224, 242, 254), ForeColor = Color.FromArgb(3, 105, 161), Font = new Font("Segoe UI", 9, FontStyle.Bold) });
            p.Controls.Add(new Label { Text = app.name, Left = 80, Top = 17, Width = 168, Height = 22, Font = new Font("Segoe UI", 9, FontStyle.Bold), ForeColor = Color.FromArgb(15, 23, 42), BackColor = Color.Transparent });
            p.Controls.Add(new Label { Text = app.description, Left = 80, Top = 42, Width = 174, Height = 32, ForeColor = Color.FromArgb(51, 65, 85), BackColor = Color.Transparent });
            p.Controls.Add(new Label { Text = app.id, Left = 80, Top = 76, Width = 176, Height = 18, ForeColor = Color.FromArgb(37, 99, 235), Font = new Font("Segoe UI", 7), BackColor = Color.Transparent });
            var cb = new CheckBox { Left = 266, Top = 41, Checked = app.selected, BackColor = Color.Transparent };
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
        private readonly Label title = new Label();
        private readonly Label subtitle = new Label();
        private readonly Button updateButton = new Button();
        private readonly ProgressBar progress = new ProgressBar();
        private readonly Image updateBanner = MainForm.LoadEmbeddedImage("assets.app-header-banner.png");
        private UpdateManifest manifest;

        public bool ContinueToApp { get; private set; }

        public UpdateForm()
        {
            Text = "GL WinTool - atualizacao";
            Width = 720;
            Height = 430;
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            BackColor = Color.FromArgb(3, 7, 18);
            Font = new Font("Segoe UI", 9F);
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);

            Paint += (s, e) =>
            {
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                using (var bg = new System.Drawing.Drawing2D.LinearGradientBrush(ClientRectangle, Color.FromArgb(2, 6, 23), Color.FromArgb(8, 47, 73), 25F))
                    e.Graphics.FillRectangle(bg, ClientRectangle);
            };

            var hero = new Panel { Left = 18, Top = 18, Width = 668, Height = 116, BackColor = Color.FromArgb(2, 6, 23) };
            hero.Paint += (s, e) =>
            {
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                if (updateBanner != null) e.Graphics.DrawImage(updateBanner, hero.ClientRectangle);
                using (var shade = new System.Drawing.Drawing2D.LinearGradientBrush(hero.ClientRectangle, Color.FromArgb(185, 3, 7, 18), Color.FromArgb(35, 3, 7, 18), 0F))
                    e.Graphics.FillRectangle(shade, hero.ClientRectangle);
            };
            Controls.Add(hero);

            var card = new Panel { Left = 64, Top = 154, Width = 580, Height = 210, BackColor = Color.FromArgb(8, 15, 30) };
            card.Paint += (s, e) =>
            {
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                using (var pen = new Pen(Color.FromArgb(37, 99, 235)))
                    e.Graphics.DrawRectangle(pen, 0, 0, card.Width - 1, card.Height - 1);
            };
            Controls.Add(card);

            var icon = new PictureBox { Width = 74, Height = 74, Left = 32, Top = 28, SizeMode = PictureBoxSizeMode.StretchImage, Image = Icon.ToBitmap(), BackColor = Color.Transparent };
            card.Controls.Add(icon);

            title.Text = "GL WinTool";
            title.ForeColor = Color.White;
            title.Font = new Font("Segoe UI", 25, FontStyle.Bold);
            title.AutoSize = true;
            title.Left = 124;
            title.Top = 30;
            title.BackColor = Color.Transparent;
            card.Controls.Add(title);

            subtitle.Text = "Verificando pacote mais recente";
            subtitle.ForeColor = Color.FromArgb(125, 211, 252);
            subtitle.Font = new Font("Segoe UI", 10, FontStyle.Bold);
            subtitle.AutoSize = true;
            subtitle.Left = 128;
            subtitle.Top = 78;
            subtitle.BackColor = Color.Transparent;
            card.Controls.Add(subtitle);

            status.Text = "Buscando atualizacao segura no GitHub...";
            status.ForeColor = Color.FromArgb(191, 219, 254);
            status.TextAlign = ContentAlignment.MiddleCenter;
            status.Left = 32;
            status.Top = 116;
            status.Width = 516;
            status.Height = 28;
            status.BackColor = Color.Transparent;
            card.Controls.Add(status);

            progress.Left = 48;
            progress.Top = 152;
            progress.Width = 484;
            progress.Height = 10;
            progress.Style = ProgressBarStyle.Marquee;
            card.Controls.Add(progress);

            updateButton.Text = "Baixar e atualizar agora";
            updateButton.Left = 182;
            updateButton.Top = 174;
            updateButton.Width = 220;
            updateButton.Height = 36;
            updateButton.FlatStyle = FlatStyle.Flat;
            updateButton.BackColor = Color.FromArgb(14, 165, 233);
            updateButton.ForeColor = Color.White;
            updateButton.Font = new Font("Segoe UI", 9, FontStyle.Bold);
            updateButton.FlatAppearance.BorderColor = Color.FromArgb(125, 211, 252);
            updateButton.FlatAppearance.MouseOverBackColor = Color.FromArgb(2, 132, 199);
            updateButton.Visible = false;
            updateButton.Click += (s, e) => ApplyUpdate();
            card.Controls.Add(updateButton);

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
                    subtitle.Text = "Atualizacao obrigatoria disponivel";
                    status.Text = "Atualizacao disponivel: " + manifest.version + ". Atualize para continuar.";
                    updateButton.Visible = true;
                    return;
                }
                subtitle.Text = "Tudo certo";
                status.Text = "Sem atualizacao disponivel.";
                var timer = new Timer { Interval = 1000 };
                timer.Tick += (s, e) => { timer.Stop(); ContinueToApp = true; Close(); };
                timer.Start();
            }
            catch
            {
                subtitle.Text = "Modo offline";
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
            updateButton.Text = "Atualizando...";
            subtitle.Text = "Baixando pacote oficial";
            status.Text = "Baixando e preparando a nova versao...";
            progress.Style = ProgressBarStyle.Marquee;
            try
            {
                var tempRoot = Path.Combine(Path.GetTempPath(), "GL-WinTool-native-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(tempRoot);
                var zip = Path.Combine(tempRoot, "GL-WinTool-Native.zip");
                using (var web = new WebClient()) web.DownloadFile(manifest.zipUrl, zip);
                status.Text = "Validando arquivos e preparando reinicio...";
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
                updateButton.Text = "Tentar novamente";
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





