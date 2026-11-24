using System;
using System.IO;
using System.Text.RegularExpressions;

// VS Code passes the same application setting to both Windows and Remote SSH.
// Keep this PATH entry stable while the versioned Windows launcher is in use.
internal static class PathLauncher
{
    private static int Main(string[] args)
    {
        try
        {
            string root = Path.Combine(Environment.GetEnvironmentVariable("LOCALAPPDATA"), "vscode-codex-account");
            string name;
            using (var stream = new FileStream(Path.Combine(root, "path-launcher-target"), FileMode.Open,
                                               FileAccess.Read, FileShare.Read | FileShare.Delete))
            using (var reader = new StreamReader(stream))
                name = reader.ReadToEnd().TrimEnd('\r', '\n');
            if (!Regex.IsMatch(name, @"\Aextension-launcher(?:-[a-fA-F0-9]{64})?\.exe\z"))
                throw new InvalidDataException();
            // Use the original stdio handles and process lifetime, including the launcher's Windows job.
            var setup = new AppDomainSetup { ApplicationBase = root };
            return AppDomain.CreateDomain("vscodex", null, setup).ExecuteAssembly(Path.Combine(root, name), args);
        }
        catch (Exception)
        {
            Console.Error.WriteLine("vscodex: could not start the installed launcher. Run install.ps1 -RemoteSsh.");
            return 1;
        }
    }
}
