using System.Diagnostics;
using GLWinTool.Models;

namespace GLWinTool.Services;

public sealed class WingetService
{
    public async Task<string> RunAsync(string action, IEnumerable<AppCatalogItem> apps)
    {
        var output = new List<string>();
        foreach (var app in apps)
        {
            output.Add($"{action}: {app.Name}");
            var args = new List<string> { action, "--id", app.Id, "--exact", "--accept-source-agreements", "--disable-interactivity" };
            if (action is "install" or "upgrade")
            {
                args.Add("--accept-package-agreements");
                args.Add("--silent");
            }
            if (action is "uninstall")
            {
                args.Add("--silent");
            }

            var result = await RunProcessAsync("winget", args);
            output.Add(result);
        }
        return string.Join(Environment.NewLine, output);
    }

    private static async Task<string> RunProcessAsync(string fileName, IReadOnlyList<string> args)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        foreach (var arg in args) psi.ArgumentList.Add(arg);

        using var process = Process.Start(psi);
        if (process is null) return "Nao foi possivel iniciar o WinGet.";

        var stdout = await process.StandardOutput.ReadToEndAsync();
        var stderr = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        return $"> winget {string.Join(" ", args)}{Environment.NewLine}{stdout}{stderr}Exit code: {process.ExitCode}";
    }
}
