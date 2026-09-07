namespace GLWinTool.Models;

public sealed class AppCatalogItem
{
    public string Name { get; set; } = "";
    public string Id { get; set; } = "";
    public string Category { get; set; } = "Geral";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "";
    public string Accent { get; set; } = "#2563EB";
    public bool Selected { get; set; }
}
