using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using Microsoft.Win32.SafeHandles;

internal static class Launcher
{
    private static readonly Regex ExtensionFolder = new Regex(
        @"\Aopenai\.chatgpt-\d+\.\d+\.\d+(?:-[a-z0-9.]+)*-win32-(x64|arm64)\z",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    private static readonly Regex AccountName = new Regex(@"\A[a-z][a-z0-9_-]{0,31}\z");

    private static string BundledBinary(string binDir)
    {
        if (String.IsNullOrWhiteSpace(binDir) || !Path.IsPathRooted(binDir))
            return null;
        var platform = new DirectoryInfo(binDir);
        var bin = platform.Parent;
        if (bin == null || bin.Parent == null ||
            !String.Equals(bin.Name, "bin", StringComparison.OrdinalIgnoreCase))
            return null;
        var extension = ExtensionFolder.Match(bin.Parent.Name);
        if (!extension.Success)
            return null;
        string expected = extension.Groups[1].Value.Equals("x64", StringComparison.OrdinalIgnoreCase)
            ? "windows-x86_64" : "windows-aarch64";
        if (!String.Equals(platform.Name, expected, StringComparison.OrdinalIgnoreCase))
            return null;
        string exe = Path.Combine(platform.FullName, "codex.exe");
        return File.Exists(exe) && File.Exists(Path.Combine(bin.Parent.FullName, "package.json"))
            ? exe : null;
    }

    // openai.chatgpt appends the bin directory of the extension that started this process.
    private static string ResolveBundledBinary()
    {
        if (Environment.GetEnvironmentVariable("CODEX_INTERNAL_ORIGINATOR_OVERRIDE") == "codex_vscode")
        {
            string[] entries = (Environment.GetEnvironmentVariable("PATH") ?? "").TrimEnd(';').Split(';');
            string appended = entries[entries.Length - 1].Trim().Trim('"');
            string candidate = BundledBinary(appended);
            if (candidate != null) return candidate;
        }

        // When invoked from a terminal, use the registered VS Code installation.
        string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                                   ".vscode", "extensions");
        string registry = Path.Combine(root, "extensions.json");
        if (File.Exists(registry))
        {
            var serializer = new JavaScriptSerializer { MaxJsonLength = Int32.MaxValue };
            var records = serializer.Deserialize<ExtensionRecord[]>(File.ReadAllText(registry));
            foreach (var record in records)
            {
                if (record.identifier == null ||
                    !String.Equals(record.identifier.id, "openai.chatgpt", StringComparison.OrdinalIgnoreCase) ||
                    !ExtensionFolder.IsMatch(record.relativeLocation ?? "")) continue;
                string platform = record.relativeLocation.EndsWith("-x64", StringComparison.OrdinalIgnoreCase)
                    ? "windows-x86_64" : "windows-aarch64";
                string candidate = BundledBinary(Path.Combine(root, record.relativeLocation, "bin", platform));
                if (candidate != null) return candidate;
            }
        }
        throw new InvalidOperationException("Install the OpenAI Codex extension in local Windows VS Code.");
    }

    public sealed class ExtensionRecord
    {
        public ExtensionIdentifier identifier { get; set; }
        public string relativeLocation { get; set; }
    }
    public sealed class ExtensionIdentifier { public string id { get; set; } }

    private static string SelectedHome()
    {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string slot;
        try
        {
            // The manager can atomically replace this file while an extension window starts.
            using (var stream = new FileStream(Path.Combine(root, "selected"), FileMode.Open,
                                               FileAccess.Read, FileShare.Read | FileShare.Delete))
            using (var reader = new StreamReader(stream))
                slot = reader.ReadToEnd().TrimEnd('\r', '\n');
        }
        catch (FileNotFoundException) { return null; }
        if (!AccountName.IsMatch(slot)) throw new InvalidDataException("Invalid selected account.");
        string home = Path.Combine(root, "accounts", slot);
        if (!File.Exists(Path.Combine(home, "auth.json")))
            throw new InvalidDataException("The selected account needs device login.");
        return home;
    }

    private static int Main(string[] args)
    {
        try
        {
            string exe = ResolveBundledBinary();
            if (args.Length == 1 && args[0] == "--vscodex-bundled-path")
            {
                Console.OutputEncoding = new UTF8Encoding(false);
                Console.WriteLine(exe);
                return 0;
            }
            string home = SelectedHome();
            string slot = home == null ? "original" : Path.GetFileName(home);
            string root = AppDomain.CurrentDomain.BaseDirectory;
            bool server = IsStdioServer(args);
            string program = exe;
            var arguments = new List<string>();
            if (server)
            {
                program = File.ReadAllText(Path.Combine(root, "python-path")).Trim();
                Environment.SetEnvironmentVariable("CODEX_HOME", File.ReadAllText(Path.Combine(root, "shared-home")).Trim());
                arguments.AddRange(new[] { program, "-I", Path.Combine(root, "backend.py"), exe, slot });
            }
            else
                arguments.Add(exe);
            if (!server && home != null)
            {
                Environment.SetEnvironmentVariable("CODEX_HOME", home);
                arguments.Add("-c");
                arguments.Add("cli_auth_credentials_store=\"file\"");
            }
            arguments.AddRange(args);
            return RunChild(program, String.Join(" ", arguments.ConvertAll(Quote).ToArray()),
                            server ? "shared." + slot : null);
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("vscodex launcher: " + error.Message);
            return 1;
        }
    }

    private static bool IsStdioServer(string[] args)
    {
        // The extension can put global config overrides before the subcommand.
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "-c" || args[i] == "--config") { i++; continue; }
            if (args[i].StartsWith("-", StringComparison.Ordinal)) continue;
            if (args[i] != "app-server") return false;
            for (int j = i + 1; j < args.Length; j++)
            {
                string arg = args[j];
                if (arg == "-h" || arg == "--help" || arg == "--print-startup-config" ||
                    arg == "help" || arg == "daemon" || arg == "proxy" ||
                    arg == "generate-ts" || arg == "generate-json-schema") return false;
                if (arg == "--listen" && j + 1 < args.Length && args[j + 1] != "stdio://") return false;
                if (arg.StartsWith("--listen=") && arg != "--listen=stdio://") return false;
            }
            return true;
        }
        return false;
    }

    private static EventWaitHandle MarkActive(string slot)
    {
        if (slot == null) return null;
        // Each VS Code window holds a handle. Windows removes the event when the
        // last one closes, including when the extension host kills the launcher.
        try { return new EventWaitHandle(true, EventResetMode.ManualReset, @"Local\vscodex.active." + slot); }
        catch (UnauthorizedAccessException) { }
        catch (System.Security.SecurityException) { }
        catch (WaitHandleCannotBeOpenedException) { }
        catch (IOException) { }
        return null;
    }

    // Microsoft C runtime argv rules: double trailing backslashes and those before quotes.
    private static string Quote(string value)
    {
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { slashes++; continue; }
            result.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
            result.Append(c);
            slashes = 0;
        }
        return result.Append('\\', slashes * 2).Append('"').ToString();
    }

    // Create the child inside the job atomically. Even an abrupt extension-host shutdown
    // closes our job handle and terminates the bundled process. The child reads the
    // extension's original pipes directly, so JSON-RPC and EOF need no relay threads.
    private static int RunChild(string exe, string commandLine, string activeSlot)
    {
        using (var job = CreateJobObject(IntPtr.Zero, null))
        using (var stdin = InheritableStdHandle(-10))
        using (var stdout = InheritableStdHandle(-11))
        using (var stderr = InheritableStdHandle(-12))
        {
            if (job.IsInvalid) throw new Win32Exception();
            var limits = new JobLimits();
            limits.basic.limitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            Check(SetInformationJobObject(job, 9, ref limits, Marshal.SizeOf(typeof(JobLimits))));
            IntPtr size = IntPtr.Zero;
            InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
            if (size == IntPtr.Zero) throw new Win32Exception();
            IntPtr attributes = Marshal.AllocHGlobal(size);
            IntPtr jobList = Marshal.AllocHGlobal(IntPtr.Size);
            bool initialized = false;
            try
            {
                Check(InitializeProcThreadAttributeList(attributes, 1, 0, ref size));
                initialized = true;
                Marshal.WriteIntPtr(jobList, job.DangerousGetHandle());
                Check(UpdateProcThreadAttribute(attributes, 0, (IntPtr)0x2000D, jobList,
                                                (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero));
                var start = new StartupInfoEx();
                start.info.size = Marshal.SizeOf(typeof(StartupInfoEx));
                start.info.flags = 0x100; // STARTF_USESTDHANDLES
                start.info.stdin = stdin.DangerousGetHandle();
                start.info.stdout = stdout.DangerousGetHandle();
                start.info.stderr = stderr.DangerousGetHandle();
                start.attributes = attributes;
                ProcessInfo child;
                Check(CreateProcess(exe, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero,
                                    true, 0x80000, IntPtr.Zero, null, ref start, out child));
                using (var thread = new SafeFileHandle(child.thread, true))
                using (var process = new SafeFileHandle(child.process, true))
                using (var active = MarkActive(activeSlot))
                {
                    if (WaitForSingleObject(process, UInt32.MaxValue) != 0)
                        throw new Win32Exception();
                    uint code;
                    Check(GetExitCodeProcess(process, out code));
                    return unchecked((int)code);
                }
            }
            finally
            {
                if (initialized) DeleteProcThreadAttributeList(attributes);
                Marshal.FreeHGlobal(jobList);
                Marshal.FreeHGlobal(attributes);
            }
        }
    }

    private static SafeFileHandle InheritableStdHandle(int index)
    {
        IntPtr handle = GetStdHandle(index);
        if (handle == IntPtr.Zero || handle == new IntPtr(-1))
            return new SafeFileHandle(IntPtr.Zero, false);
        IntPtr process = GetCurrentProcess();
        SafeFileHandle copy;
        Check(DuplicateHandle(process, handle, process, out copy, 0, true, 2));
        return copy;
    }

    private static void Check(bool success) { if (!success) throw new Win32Exception(); }

    [StructLayout(LayoutKind.Sequential)]
    private struct StartupInfo
    {
        public int size;
        public IntPtr reserved, desktop, title;
        public int x, y, width, height, columns, rows, fill, flags;
        public short show, reservedSize;
        public IntPtr reservedData, stdin, stdout, stderr;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct StartupInfoEx { public StartupInfo info; public IntPtr attributes; }
    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInfo { public IntPtr process, thread; public int processId, threadId; }
    [StructLayout(LayoutKind.Sequential)]
    private struct BasicJobLimits
    {
        public long processTime, jobTime;
        public uint limitFlags;
        public UIntPtr minWorkingSet, maxWorkingSet;
        public uint processLimit;
        public UIntPtr affinity;
        public uint priorityClass, schedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct JobLimits
    {
        public BasicJobLimits basic;
        public ulong readOps, writeOps, otherOps, readBytes, writeBytes, otherBytes;
        public UIntPtr processMemory, jobMemory, peakProcessMemory, peakJobMemory;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateJobObject(IntPtr security, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(SafeFileHandle job, int infoClass, ref JobLimits info, int length);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool UpdateProcThreadAttribute(IntPtr list, int flags, IntPtr attribute, IntPtr value,
                                                        IntPtr size, IntPtr previous, IntPtr returned);
    [DllImport("kernel32.dll")] private static extern void DeleteProcThreadAttributeList(IntPtr list);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcess(string exe, StringBuilder args, IntPtr processSecurity,
                                            IntPtr threadSecurity, bool inheritHandles, uint flags,
                                            IntPtr environment, string directory, ref StartupInfoEx start, out ProcessInfo process);
    [DllImport("kernel32.dll")] private static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll")] private static extern IntPtr GetStdHandle(int number);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool DuplicateHandle(IntPtr sourceProcess, IntPtr source, IntPtr targetProcess,
                                              out SafeFileHandle target, int access, bool inherit, uint options);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(SafeFileHandle handle, uint millis);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(SafeFileHandle handle, out uint code);
}
