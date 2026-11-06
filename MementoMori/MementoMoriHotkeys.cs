using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

internal static class MementoMoriHotkeys
{
    private const int HotkeyId = 17061;
    private const uint HotkeyMessage = 0x0312;
    private static readonly string Root = AppDomain.CurrentDomain.BaseDirectory;
    private static readonly string Rainmeter = Path.Combine(Root, "Rainmeter.exe");

    [StructLayout(LayoutKind.Sequential)]
    private struct Message
    {
        public IntPtr Window;
        public uint Kind;
        public UIntPtr WParam;
        public IntPtr LParam;
        public uint Time;
        public int X;
        public int Y;
        public uint Private;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr window, int id);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetMessage(out Message message, IntPtr window, uint first, uint last);

    private static void Log(string message)
    {
        File.AppendAllText(Path.Combine(Root, "Hotkey.log"), DateTime.Now.ToString("o") + " " + message + Environment.NewLine);
    }

    private static Process Start(string arguments)
    {
        return Process.Start(new ProcessStartInfo(Rainmeter, arguments)
        {
            WorkingDirectory = Root,
            UseShellExecute = false,
            CreateNoWindow = true
        });
    }

    private static bool IsMeterRunning()
    {
        foreach (Process process in Process.GetProcessesByName("Rainmeter"))
        {
            using (process)
            {
                try
                {
                    if (String.Equals(process.MainModule.FileName, Rainmeter, StringComparison.OrdinalIgnoreCase)) return true;
                }
                catch (Win32Exception) { }
                catch (InvalidOperationException) { }
            }
        }
        return false;
    }

    private static void Command(string arguments)
    {
        using (Process process = Start(arguments))
        {
            if (!process.WaitForExit(5000)) throw new TimeoutException("Rainmeter control command timed out.");
            if (process.ExitCode != 0) throw new InvalidOperationException("Rainmeter control command exited " + process.ExitCode);
        }
    }

    private static void Toggle()
    {
        if (IsMeterRunning())
        {
            Command("!Toggle \"MementoMori\"");
            Log("TOGGLE delivered");
            return;
        }
        using (Process process = Start(""))
        {
            if (!process.WaitForInputIdle(10000)) throw new TimeoutException("Rainmeter did not start.");
        }
        Command("!ActivateConfig \"MementoMori\" \"Meter.ini\"");
        Command("!Show \"MementoMori\"");
        Log("START and SHOW delivered");
    }

    [STAThread]
    private static int Main()
    {
        bool first;
        using (Mutex mutex = new Mutex(true, "Local\\MementoMori.Hotkey", out first))
        {
            if (!first) return 0;
            bool registered = false;
            try
            {
                registered = RegisterHotKey(IntPtr.Zero, HotkeyId, 0x4003, 0x4D);
                if (!registered) throw new Win32Exception(Marshal.GetLastWin32Error(), "Ctrl+Alt+M could not be registered");
                Log("REGISTERED Ctrl+Alt+M");
                Message message;
                int result;
                while ((result = GetMessage(out message, IntPtr.Zero, 0, 0)) > 0)
                {
                    if (message.Kind != HotkeyMessage || message.WParam.ToUInt64() != HotkeyId) continue;
                    Log("KEYPRESS");
                    try { Toggle(); }
                    catch (Exception error) { Log("ERROR " + error.Message); }
                }
                if (result < 0) throw new Win32Exception(Marshal.GetLastWin32Error(), "Hotkey message loop failed");
                return 0;
            }
            catch (Exception error)
            {
                Log("ERROR " + error.Message);
                return 1;
            }
            finally
            {
                if (registered) UnregisterHotKey(IntPtr.Zero, HotkeyId);
            }
        }
    }
}
