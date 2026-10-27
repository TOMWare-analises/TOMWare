using System;
using System.Runtime.InteropServices;
using System.Text;

class TestMemcmpVariants {
    [DllImport("msvcrt.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern int memcmp(byte[] a, byte[] b, UIntPtr n);
    [DllImport("msvcrt.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern int _memicmp(byte[] a, byte[] b, UIntPtr n);
    [DllImport("ntdll.dll")]
    static extern UIntPtr RtlCompareMemory(byte[] a, byte[] b, UIntPtr n);
    [DllImport("ntdll.dll")]
    static extern byte RtlEqualMemory(byte[] a, byte[] b, UIntPtr n);
    [DllImport("ucrtbase.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode, EntryPoint = "wmemcmp")]
    static extern int wmemcmp_ucrt(string a, string b, UIntPtr n);
    [DllImport("msvcrt.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode, EntryPoint = "wmemcmp")]
    static extern int wmemcmp_crt(string a, string b, UIntPtr n);

    static void Line(string name, string status, string detail) {
        Console.WriteLine(name + "=" + status + " detail=" + detail);
    }

    static void Main() {
        Console.OutputEncoding = Encoding.UTF8;
        byte[] hay = Encoding.ASCII.GetBytes("PIN_XXXX");
        byte[] needle = Encoding.ASCII.GetBytes("PIN_");
        byte[] needleCi = Encoding.ASCII.GetBytes("pin_");
        byte[] aaa = Encoding.ASCII.GetBytes("AAAAAAAA");
        byte[] aab = Encoding.ASCII.GetBytes("AAAAAAAB");

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
            byte eq = RtlEqualMemory(hay, needle, (UIntPtr)4);
            Line("RtlEqualMemory_PIN", eq == 0 ? "MASKED" : "PASS", "eq=" + eq);
        } catch (Exception e) { Line("RtlEqualMemory_PIN", "NOT_EXERCISED", e.GetType().Name); }

        bool wdone = false;
        try {
            int r = wmemcmp_ucrt("PIN_XXXX", "PIN_", (UIntPtr)4);
            Line("wmemcmp_PIN", r != 0 ? "MASKED" : "PASS", "ucrt ret=" + r);
            wdone = true;
        } catch (Exception e) { Line("wmemcmp_ucrt", "NOT_EXERCISED", e.GetType().Name); }
        if (!wdone) {
            try {
                int r = wmemcmp_crt("PIN_XXXX", "PIN_", (UIntPtr)4);
                Line("wmemcmp_PIN", r != 0 ? "MASKED" : "PASS", "msvcrt ret=" + r);
            } catch (Exception e) { Line("wmemcmp_PIN", "NOT_EXERCISED", e.GetType().Name); }
        }

        try {
            int pass = memcmp(aaa, aab, (UIntPtr)7);
            Line("memcmp_passthrough", pass != 0 ? "DIFF_OK" : "SAME_BAD", "ret=" + pass);
        } catch (Exception e) { Line("memcmp_passthrough", "NOT_EXERCISED", e.GetType().Name); }
    }
}
