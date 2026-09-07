using System.IO;
using System.Text.Json;
using GLWinTool.Models;

namespace GLWinTool.Services;

public sealed class CatalogService
{
    private readonly string _root;

    public CatalogService(string root) => _root = root;

    public IReadOnlyList<AppCatalogItem> LoadApps()
    {
        var path = Path.Combine(_root, "config", "apps.json");
        if (!File.Exists(path)) return [];

        var json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<List<AppCatalogItem>>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? [];
    }
}
