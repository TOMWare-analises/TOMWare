using System;
using System.Runtime.InteropServices;
using System.Text;

class TestMemcmpVariantsV3 {
    [DllImport("msvcrt.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern int memcmp(byte[] a, byte[] b, UIntPtr n);
    [DllImport("msvcrt.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern int _memicmp(byte[] a, byte[] b, UIntPtr n);
    [DllImport("ntdll.dll")]
    static extern UIntPtr RtlCompareMemory(byte[] a, byte[] b, UIntPtr n);
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    static extern IntPtr LoadLibraryA(string name);
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    static extern IntPtr GetProcAddress(IntPtr mod, string name);

    delegate int MemCmpFn(byte[] a, byte[] b, UIntPtr n);
    delegate int WMemCmpFn([MarshalAs(UnmanagedType.LPWStr)] string a, [MarshalAs(UnmanagedType.LPWStr)] string b, UIntPtr n);
    delegate byte RtlEqFn(byte[] a, byte[] b, UIntPtr n);
    delegate int MemicmpLFn(byte[] a, byte[] b, UIntPtr n, IntPtr locale);

    static void Line(string name, string status, string detail) {
        Console.WriteLine(name + "=" + status + " detail=" + detail);
    }

    static void TryExport(string dll, string symbol) {
        try {
            IntPtr h = LoadLibraryA(dll);
            if (h == IntPtr.Zero) { Line(symbol + "_export", "NOT_EXERCISED", "LoadLibrary " + dll); return; }
            IntPtr p = GetProcAddress(h, symbol);
            Line(symbol + "_export", p != IntPtr.Zero ? "FOUND" : "ABSENT", dll);
        } catch (Exception e) {
            Line(symbol + "_export", "NOT_EXERCISED", e.GetType().Name);
        }
    }

    static void Main() {
        Console.OutputEncoding = Encoding.UTF8;
        byte[] hay = Encoding.ASCII.GetBytes("PIN_XXXX");
        byte[] needle = Encoding.ASCII.GetBytes("PIN_");
        byte[] needleCi = Encoding.ASCII.GetBytes("pin_");
        byte[] aaa = Encoding.ASCII.GetBytes("AAAAAAAA");
        byte[] aab = Encoding.ASCII.GetBytes("AAAAAAAB");
        byte[] empty = new byte[0];

        try {
            int r = memcmp(hay, needle, (UIntPtr)4);
            Line("memcmp_PIN", r != 0 ? "MASKED" : "PASS", "ret=" + r);
        } catch (Exception e) { Line("memcmp_PIN", "NOT_EXERCISED", e.GetType().Name); }

        try {
            int r = _memicmp(hay, needleCi, (UIntPtr)4);
            Line("memicmp_PIN", r != 0 ? "MASKED" : "PASS", "ret=" + r);
        } catch (Exception e) { Line("memicmp_PIN", "NOT_EXERCISED", e.GetType().Name); }

        try {
            UIntPtr n = RtlCompareMemory(hay, needle, (UIntPtr)4);
            Line("RtlCompareMemory_PIN", n.ToUInt64() < 4 ? "MASKED" : "PASS", "n=" + n);
        } catch (Exception e) { Line("RtlCompareMemory_PIN", "NOT_EXERCISED", e.GetType().Name); }

        try {
            int z = memcmp(empty, empty, UIntPtr.Zero);
            Line("memcmp_len0", z == 0 ? "OK" : "UNEXPECTED", "ret=" + z);
        } catch (Exception e) { Line("memcmp_len0", "NOT_EXERCISED", e.GetType().Name); }

        try {
            int same = memcmp(aaa, aaa, (UIntPtr)8);
            Line("memcmp_same", same == 0 ? "OK" : "UNEXPECTED", "ret=" + same);
        } catch (Exception e) { Line("memcmp_same", "NOT_EXERCISED", e.GetType().Name); }

        try {
            int diff = memcmp(aaa, aab, (UIntPtr)8);
            Line("memcmp_passthrough", diff != 0 ? "DIFF_OK" : "SAME_UNEXPECTED", "ret=" + diff + ";n=8;convention=neg_if_a_lt_b");
        } catch (Exception e) { Line("memcmp_passthrough", "NOT_EXERCISED", e.GetType().Name); }

        try {
            int same = _memicmp(aaa, aaa, (UIntPtr)8);
            Line("memicmp_same", same == 0 ? "OK" : "UNEXPECTED", "ret=" + same);
            int diff = _memicmp(aaa, aab, (UIntPtr)8);
            Line("memicmp_passthrough", diff != 0 ? "DIFF_OK" : "SAME_UNEXPECTED", "ret=" + diff + ";n=8");
        } catch (Exception e) { Line("memicmp_passthrough", "NOT_EXERCISED", e.GetType().Name); }

        try {
            UIntPtr same = RtlCompareMemory(aaa, aaa, (UIntPtr)8);
            Line("RtlCompareMemory_same", same.ToUInt64() == 8 ? "OK" : "UNEXPECTED", "n=" + same);
            UIntPtr diff = RtlCompareMemory(aaa, aab, (UIntPtr)8);
            Line("RtlCompareMemory_passthrough", diff.ToUInt64() < 8 ? "DIFF_OK" : "SAME_UNEXPECTED", "n=" + diff + ";convention=bytes_matched");
        } catch (Exception e) { Line("RtlCompareMemory_passthrough", "NOT_EXERCISED", e.GetType().Name); }

        foreach (var pair in new[] {
            new[] { "ntdll.dll", "RtlEqualMemory" },
            new[] { "ucrtbase.dll", "wmemcmp" },
            new[] { "msvcrt.dll", "wmemcmp" },
            new[] { "ucrtbase.dll", "memcmp_s" },
            new[] { "ucrtbase.dll", "wmemcmp_s" },
            new[] { "msvcrt.dll", "bcmp" },
            new[] { "msvcrt.dll", "_memicmp_l" },
        }) TryExport(pair[0], pair[1]);

        try {
            IntPtr ntdll = LoadLibraryA("ntdll.dll");
            IntPtr p = ntdll == IntPtr.Zero ? IntPtr.Zero : GetProcAddress(ntdll, "RtlEqualMemory");
            if (p == IntPtr.Zero) Line("RtlEqualMemory_PIN", "NOT_EXERCISED", "GetProcAddress ABSENT");
            else {
                var fn = (RtlEqFn)Marshal.GetDelegateForFunctionPointer(p, typeof(RtlEqFn));
                byte eq = fn(hay, needle, (UIntPtr)4);
                Line("RtlEqualMemory_PIN", eq == 0 ? "MASKED" : "PASS", "eq=" + eq);
            }
        } catch (Exception e) { Line("RtlEqualMemory_PIN", "NOT_EXERCISED", e.GetType().Name); }

        bool wdone = false;
        foreach (var dll in new[] { "ucrtbase.dll", "msvcrt.dll" }) {
            if (wdone) break;
            try {
                IntPtr h = LoadLibraryA(dll);
                IntPtr p = h == IntPtr.Zero ? IntPtr.Zero : GetProcAddress(h, "wmemcmp");
                if (p == IntPtr.Zero) { Line("wmemcmp_export", "ABSENT", dll); continue; }
                var fn = (WMemCmpFn)Marshal.GetDelegateForFunctionPointer(p, typeof(WMemCmpFn));
                int r = fn("PIN_XXXX", "PIN_", (UIntPtr)4);
                Line("wmemcmp_PIN", r != 0 ? "MASKED" : "PASS", dll + " ret=" + r);
                wdone = true;
            } catch (Exception e) { Line("wmemcmp_PIN", "NOT_EXERCISED", dll + " " + e.GetType().Name); }
        }
        if (!wdone) Line("wmemcmp_PIN", "NOT_EXERCISED", "no export");

        try {
            IntPtr h = LoadLibraryA("msvcrt.dll");
            IntPtr p = h == IntPtr.Zero ? IntPtr.Zero : GetProcAddress(h, "_memicmp_l");
            if (p == IntPtr.Zero) Line("memicmp_l_PIN", "NOT_EXERCISED", "GetProcAddress ABSENT");
            else {
                var fn = (MemicmpLFn)Marshal.GetDelegateForFunctionPointer(p, typeof(MemicmpLFn));
                int r = fn(hay, needleCi, (UIntPtr)4, IntPtr.Zero);
                Line("memicmp_l_PIN", r != 0 ? "MASKED" : "PASS", "ret=" + r + ";locale=0");
                int same = fn(aaa, aaa, (UIntPtr)8, IntPtr.Zero);
                Line("memicmp_l_same", same == 0 ? "OK" : "UNEXPECTED", "ret=" + same);
                int diff = fn(aaa, aab, (UIntPtr)8, IntPtr.Zero);
                Line("memicmp_l_passthrough", diff != 0 ? "DIFF_OK" : "SAME_UNEXPECTED", "ret=" + diff + ";n=8");
            }
        } catch (Exception e) { Line("memicmp_l_PIN", "NOT_EXERCISED", e.GetType().Name); }
    }
}
