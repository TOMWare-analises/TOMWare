using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

class TestConcurrentWaitsLogged {
    [DllImport("kernel32.dll")]
    static extern bool QueryPerformanceCounter(out long c);
    [DllImport("kernel32.dll")]
    static extern bool QueryPerformanceFrequency(out long f);
    [DllImport("kernel32.dll")]
    static extern uint GetCurrentThreadId();

    static long Freq;
    static string LogPath;
    static int Seq;

    static long Qpc() {
        long c;
        QueryPerformanceCounter(out c);
        return c;
    }

    static void Ev(string scenario, string api, int requested, long start, long end, string extra) {
        Seq++;
        double ms = Freq > 0 ? (end - start) * 1000.0 / Freq : 0;
        int pid = Process.GetCurrentProcess().Id;
        uint tid = GetCurrentThreadId();
        string line = string.Format(
            "{{\"seq\":{0},\"pid\":{1},\"tid\":{2},\"scenario\":\"{3}\",\"wait_api\":\"{4}\",\"requested_wait_ms\":{5},\"start_reference_ns\":{6},\"end_reference_ns\":{7},\"observed_wait_ms\":{8:0.###},\"extra\":\"{9}\"}}",
            Seq, pid, tid, scenario, api, requested,
            start * 1000000000L / Math.Max(Freq, 1),
            end * 1000000000L / Math.Max(Freq, 1),
            ms, extra.Replace("\\", "/").Replace("\"", "'"));
        File.AppendAllText(LogPath, line + "\r\n");
        Console.WriteLine("EV " + line);
    }

    static void Main(string[] args) {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        QueryPerformanceFrequency(out Freq);
        string dir = args.Length > 0 ? args[0] : ".";
        Directory.CreateDirectory(dir);
        LogPath = Path.Combine(dir, "events.jsonl");
        const int sleepMs = 200;

        long s0 = Qpc();
        Thread.Sleep(sleepMs);
        long s1 = Qpc();
        Thread.Sleep(sleepMs);
        long s2 = Qpc();
        Ev("seq_a", "Thread.Sleep", sleepMs, s0, s1, "first");
        Ev("seq_b", "Thread.Sleep", sleepMs, s1, s2, "second");

        long p0 = Qpc();
        long t1s = 0, t1e = 0, t2s = 0, t2e = 0;
        var th1 = new Thread(() => { t1s = Qpc(); Thread.Sleep(sleepMs); t1e = Qpc(); });
        var th2 = new Thread(() => { t2s = Qpc(); Thread.Sleep(sleepMs); t2e = Qpc(); });
        th1.Start(); th2.Start();
        th1.Join(); th2.Join();
        long p1 = Qpc();
        Ev("par_wall", "Join", sleepMs, p0, p1, "two_threads");
        Ev("par_t1", "Thread.Sleep", sleepMs, t1s, t1e, "overlap");
        Ev("par_t2", "Thread.Sleep", sleepMs, t2s, t2e, "overlap");
        double wallMs = (p1 - p0) * 1000.0 / Freq;
        double sumMs = (t1e - t1s + t2e - t2s) * 1000.0 / Freq;
        Console.WriteLine("overlap_wall_ms=" + wallMs.ToString("0.###"));
        Console.WriteLine("overlap_sum_ms=" + sumMs.ToString("0.###"));
        Console.WriteLine("double_count_risk=" + (sumMs > wallMs * 1.5 ? "YES" : "NO"));

        long a = Environment.TickCount;
        long c0 = Qpc();
        Thread.Sleep(50);
        long c1 = Qpc();
        long b = Environment.TickCount;
        long delta = b - a;
        Ev("tick_sleep50", "TickCount+Sleep", 50, c0, c1, "tick_delta=" + delta);
        Console.WriteLine("tick_delta_ms=" + delta);
        Console.WriteLine("monotonic=" + (delta >= 0));
        Console.WriteLine("qpc_sleep50_ms=" + ((c1 - c0) * 1000.0 / Freq).ToString("0.###"));

        long w0 = Qpc();
        using (var ev = new ManualResetEvent(false)) {
            ThreadPool.QueueUserWorkItem(_ => { Thread.Sleep(30); ev.Set(); });
            ev.WaitOne(500);
        }
        long w1 = Qpc();
        Ev("alertable", "WaitOne", 500, w0, w1, "early");
        Console.WriteLine("alertable_ms=" + ((w1 - w0) * 1000.0 / Freq).ToString("0.###"));

        double seqMs = (s2 - s0) * 1000.0 / Freq;
        Console.WriteLine("seq_ms=" + seqMs.ToString("0.###"));
        Console.WriteLine("par_ms=" + wallMs.ToString("0.###"));
        bool overlapOk = wallMs < seqMs;
        bool noBack = delta >= 0;
        Console.WriteLine(overlapOk && noBack ? "WAIT_MODEL_OK" : "WAIT_MODEL_CHECK");
    }
}
