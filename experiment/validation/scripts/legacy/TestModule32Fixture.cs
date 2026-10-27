using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

class TestModule32Fixture {
    const uint TH32CS_SNAPMODULE = 0x00000008;
    const uint TH32CS_SNAPMODULE32 = 0x00000010;
    const int MAX_MODULE_NAME32 = 255;
    const int MAX_PATH = 260;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    struct MODULEENTRY32 {
        public uint dwSize;
        public uint th32ModuleID;
        public uint th32ProcessID;
        public uint GlblcntUsage;
        public uint ProccntUsage;
        public IntPtr modBaseAddr;
        public uint modBaseSize;
        public IntPtr hModule;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = MAX_MODULE_NAME32 + 1)]
        public string szModule;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = MAX_PATH)]
        public string szExePath;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern bool Module32First(IntPtr h, ref MODULEENTRY32 me);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern bool Module32Next(IntPtr h, ref MODULEENTRY32 me);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr LoadLibraryW(string path);

    static void Main() {
        Console.OutputEncoding = Encoding.UTF8;
        string src = Path.Combine(Environment.SystemDirectory, "version.dll");
        string dest = Path.Combine(Path.GetTempPath(), "pinvm.dll");
        File.Copy(src, dest, true);
        IntPtr loaded = LoadLibraryW(dest);
        Console.WriteLine("fixture_src=" + src);
        Console.WriteLine("fixture_path=" + dest);
        Console.WriteLine("fixture_loaded=" + (loaded != IntPtr.Zero));
        Console.WriteLine("fixture_note=copy_of_version.dll_named_pinvm.dll_not_real_pin");

        IntPtr snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, 0);
        if (snap == (IntPtr)(-1)) {
            Console.WriteLine("SNAPSHOT_FAIL " + Marshal.GetLastWin32Error());
            return;
        }
        var names = new List<string>();
        var me = new MODULEENTRY32();
        me.dwSize = (uint)Marshal.SizeOf(typeof(MODULEENTRY32));
        bool ok = Module32First(snap, ref me);
        int steps = 0;
        while (ok) {
            steps++;
            if (!string.IsNullOrEmpty(me.szModule)) names.Add(me.szModule);
            ok = Module32Next(snap, ref me);
        }
        CloseHandle(snap);

        int pinish = 0, kernel32 = 0, fixture = 0;
        foreach (var n in names) {
            string l = n.ToLowerInvariant();
            if (l == "pinvm.dll") { pinish++; fixture++; }
            if (l.Contains("pinipc") || l == "pin.exe" || l.Contains("tomware")) pinish++;
            if (l == "kernel32.dll") kernel32++;
        }
        Console.WriteLine("module_count=" + names.Count);
        Console.WriteLine("enum_steps=" + steps);
        Console.WriteLine("terminated=" + (!ok));
        Console.WriteLine("kernel32=" + kernel32);
        Console.WriteLine("fixture_pinvm=" + fixture);
        Console.WriteLine("pinish=" + pinish);
        Console.WriteLine(kernel32 > 0 && !ok && names.Count > 0 ? "ENUM_OK" : "ENUM_FAIL");
    }
}
