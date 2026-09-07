using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;
using GLWinTool.Models;
using GLWinTool.Services;

namespace GLWinTool;

public partial class MainWindow : Window
{
    private readonly string _root = AppContext.BaseDirectory;
    private readonly WingetService _winget = new();
    private List<AppCatalogItem> _apps = [];

    public MainWindow()
    {
        InitializeComponent();
        LoadBranding();
        LoadCatalog();
    }

    private void LoadBranding()
    {
        var logo = Path.Combine(_root, "assets", "readme", "glab-mark.png");
        if (File.Exists(logo))
        {
            LogoImage.Source = new BitmapImage(new Uri(logo));
        }
    }

    private void LoadCatalog()
    {
        _apps = new CatalogService(_root).LoadApps().ToList();
        AppsList.ItemsSource = _apps;
        StatusText.Text = $"{_apps.Count} apps carregados";
        UpdateSelection();
        Log("GL WinTool nativo iniciado.");
    }

    private IEnumerable<AppCatalogItem> SelectedApps() => _apps.Where(x => x.Selected);

    private async Task RunWinget(string action, IEnumerable<AppCatalogItem> apps)
    {
        var selected = apps.ToList();
        if (selected.Count == 0)
        {
            Log("Nenhum app selecionado.");
            return;
        }
        IsEnabled = false;
        try
        {
            Log(await _winget.RunAsync(action, selected));
        }
        finally
        {
            IsEnabled = true;
        }
    }

    private void Log(string message)
    {
        LogText.Text += $"[{DateTime.Now:HH:mm:ss}] {message}{Environment.NewLine}";
    }

    private void UpdateSelection()
    {
        SelectionText.Text = $"Selecionados: {SelectedApps().Count()}";
    }

    private async void InstallSelected_Click(object sender, RoutedEventArgs e) => await RunWinget("install", SelectedApps());
    private async void UpgradeSelected_Click(object sender, RoutedEventArgs e) => await RunWinget("upgrade", SelectedApps());
    private async void UninstallSelected_Click(object sender, RoutedEventArgs e) => await RunWinget("uninstall", SelectedApps());
    private async void UpgradeAll_Click(object sender, RoutedEventArgs e) => await RunWinget("upgrade", _apps);

    private void ClearSelection_Click(object sender, RoutedEventArgs e)
    {
        foreach (var app in _apps) app.Selected = false;
        AppsList.Items.Refresh();
        UpdateSelection();
    }

    private void AppCheck_Click(object sender, RoutedEventArgs e) => UpdateSelection();

    private void SearchBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        var q = SearchBox.Text.Trim();
        AppsList.ItemsSource = string.IsNullOrWhiteSpace(q)
            ? _apps
            : _apps.Where(x =>
                x.Name.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                x.Id.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                x.Description.Contains(q, StringComparison.OrdinalIgnoreCase)).ToList();
    }
}
