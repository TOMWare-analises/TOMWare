using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

class TestWaitModelV3 {
    [DllImport("kernel32.dll")] static extern bool QueryPerformanceCounter(out long c);
    [DllImport("kernel32.dll")] static extern bool QueryPerformanceFrequency(out long f);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll")] static extern uint SleepEx(uint ms, bool alertable);
    [DllImport("kernel32.dll", SetLastError = true)] static extern uint QueueUserAPC(ApcProc fn, IntPtr thread, UIntPtr data);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenThread(uint access, bool inherit, uint tid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    const uint THREAD_SET_CONTEXT = 0x0010;
    const uint WAIT_IO_COMPLETION = 0x000000C0;
    delegate void ApcProc(UIntPtr ctx);
    static readonly ApcProc KeepApc = DummyApc;
    static int ApcRan;
    static void DummyApc(UIntPtr ctx) { Interlocked.Increment(ref ApcRan); }

    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
    static readonly object LogLock = new object();
    static long Freq;
    static string LogPath;
    static string RunId;
    static int Seq;
    static long t1s, t1e, t2s, t2e;

    static long Qpc() {
        long c;
        QueryPerformanceCounter(out c);
        return c;
    }

    static double ToNs(long ticks) {
        return Freq > 0 ? ticks * 1000000000.0 / Freq : 0;
    }

    static double ToMs(long ticks) {
        return Freq > 0 ? ticks * 1000.0 / Freq : 0;
    }

    static void Ev(string scenario, string api, int requested, long start, long end, uint tid, string extra) {
        int n = Interlocked.Increment(ref Seq);
        double ms = ToMs(end - start);
        string line = string.Format(Inv,
            "{{\"run_id\":\"{0}\",\"seq\":{1},\"pid\":{2},\"tid\":{3},\"scenario\":\"{4}\",\"wait_api\":\"{5}\",\"requested_wait_ms\":{6},\"qpc_freq\":{7},\"qpc_start\":{8},\"qpc_end\":{9},\"start_reference_ns\":{10:0.###},\"end_reference_ns\":{11:0.###},\"observed_wait_ms\":{12:0.###},\"extra\":\"{13}\"}}",
            RunId, n, Process.GetCurrentProcess().Id, tid, scenario, api, requested,
            Freq, start, end, ToNs(start), ToNs(end), ms,
            extra.Replace("\\", "/").Replace("\"", "'"));
        lock (LogLock) {
            File.AppendAllText(LogPath, line + "\r\n");
            Console.WriteLine("EV " + line);
        }
    }

    static void Main(string[] args) {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        Thread.CurrentThread.CurrentCulture = Inv;
        QueryPerformanceFrequency(out Freq);
        Console.WriteLine("qpc_freq=" + Freq);
        Console.WriteLine("pin_expected=3.28.98749");
        string dir = args.Length > 0 ? args[0] : ".";
        Directory.CreateDirectory(dir);
        LogPath = Path.Combine(dir, "events.jsonl");
        RunId = args.Length > 1 ? args[1] : Guid.NewGuid().ToString("N");
        File.WriteAllText(Path.Combine(dir, "run_id.txt"), RunId);
        const int sleepMs = 200;
        const int clockReads = 256;

        uint mainTid = GetCurrentThreadId();

        long s0 = Qpc();
        Thread.Sleep(sleepMs);
        long s1 = Qpc();
        Thread.Sleep(sleepMs);
        long s2 = Qpc();
        Ev("seq_a", "Thread.Sleep", sleepMs, s0, s1, mainTid, "first");
        Ev("seq_b", "Thread.Sleep", sleepMs, s1, s2, mainTid, "second");

        var arrived = new CountdownEvent(2);
        var startSleep = new ManualResetEvent(false);
        uint tid1 = 0, tid2 = 0;
        var th1 = new Thread(() => {
            try {
                tid1 = GetCurrentThreadId();
                Ev("barrier_arrived", "arrive", 0, Qpc(), Qpc(), tid1, "t1");
                arrived.Signal();
                startSleep.WaitOne();
                Interlocked.Exchange(ref t1s, Qpc());
                Thread.Sleep(sleepMs);
                Interlocked.Exchange(ref t1e, Qpc());
                Ev("par_t1", "Thread.Sleep", sleepMs, t1s, t1e, tid1, "after_barrier");
            } catch (Exception ex) {
                Console.WriteLine("TH1_ERR " + ex.GetType().Name + " " + ex.Message);
            }
        });
        var th2 = new Thread(() => {
            try {
                tid2 = GetCurrentThreadId();
                Ev("barrier_arrived", "arrive", 0, Qpc(), Qpc(), tid2, "t2");
                arrived.Signal();
                startSleep.WaitOne();
                Interlocked.Exchange(ref t2s, Qpc());
                Thread.Sleep(sleepMs);
                Interlocked.Exchange(ref t2e, Qpc());
                Ev("par_t2", "Thread.Sleep", sleepMs, t2s, t2e, tid2, "after_barrier");
            } catch (Exception ex) {
                Console.WriteLine("TH2_ERR " + ex.GetType().Name + " " + ex.Message);
            }
        });
        var sampler = new Thread(() => {
            try {
                startSleep.WaitOne();
                while (Interlocked.Read(ref t1s) == 0 || Interlocked.Read(ref t2s) == 0) { }
                long win0 = Qpc();
                long span = Freq > 0 ? Freq * sleepMs / 1000 : sleepMs;
                if (span < clockReads) span = clockReads;
                int qreg = 0, treg = 0;
                long pq = Qpc();
                int pt = Environment.TickCount;
                long firstQ = pq;
                int firstTick = pt;
                long lastQ = pq;
                int lastTick = pt;
                for (int i = 0; i < clockReads; i++) {
                    long due = win0 + span * (i + 1) / clockReads;
                    while (Qpc() < due) { }
                    long q = Qpc();
                    int t = Environment.TickCount;
                    if (q < pq) qreg++;
                    if (t < pt) treg++;
                    pq = q;
                    pt = t;
                    lastQ = q;
                    lastTick = t;
                }
                long win1 = Qpc();
                Ev("clock_during_overlap", "TickCount+QPC", sleepMs, win0, win1, GetCurrentThreadId(),
                    "reads=" + clockReads + ";qpc_regress=" + qreg + ";tick_regress=" + treg
                    + ";qpc_first=" + firstQ + ";qpc_last=" + lastQ
                    + ";tick_first=" + firstTick + ";tick_last=" + lastTick
                    + ";t1=" + tid1 + ";t2=" + tid2 + ";no_sleep2=1");
            } catch (Exception ex) {
                Console.WriteLine("SAMP_ERR " + ex.GetType().Name + " " + ex.Message);
            }
        });
        long create0 = Qpc();
        th1.Start();
        th2.Start();
        sampler.Start();
        arrived.Wait();
        Console.WriteLine("barrier_both_arrived=True t1=" + tid1 + " t2=" + tid2);
        long geo0 = Qpc();
        startSleep.Set();
        th1.Join();
        th2.Join();
        sampler.Join();
        long geo1 = Qpc();
        Ev("par_wall_incl_create", "Join", sleepMs, create0, geo1, mainTid, "includes_thread_create");
        Ev("par_wall_after_barrier", "Join", sleepMs, geo0, geo1, mainTid, "geometry_window");

        long inter = Math.Max(0, Math.Min(t1e, t2e) - Math.Max(t1s, t2s));
        long uni = Math.Max(t1e, t2e) - Math.Min(t1s, t2s);
        Console.WriteLine("intersect_ms=" + ToMs(inter).ToString("0.###", Inv));
        Console.WriteLine("union_ms=" + ToMs(uni).ToString("0.###", Inv));
        Console.WriteLine("overlap_frac=" + (uni > 0 ? (ToMs(inter) / ToMs(uni)).ToString("0.###", Inv) : "0"));
        Console.WriteLine("par_t1_tid=" + tid1);
        Console.WriteLine("par_t2_tid=" + tid2);
        Console.WriteLine("tids_distinct=" + (tid1 != 0 && tid2 != 0 && tid1 != tid2));

        long a = Environment.TickCount;
        long c0 = Qpc();
        Thread.Sleep(50);
        long c1 = Qpc();
        long b = Environment.TickCount;
        Ev("tick_sleep50", "TickCount+Sleep", 50, c0, c1, mainTid, "tick_delta=" + (b - a));
        Console.WriteLine("tick_delta_ms=" + (b - a));
        Console.WriteLine("tick_pair_monotonic=" + (b >= a));

        int qpcRegress = 0, tickRegress = 0;
        long prevQ = Qpc();
        int prevT = Environment.TickCount;
        long clk0 = Qpc();
        for (int i = 0; i < 1000; i++) {
            long q = Qpc();
            int t = Environment.TickCount;
            if (q < prevQ) qpcRegress++;
            if (t < prevT) tickRegress++;
            prevQ = q;
            prevT = t;
        }
        long clk1 = Qpc();
        Ev("clock_burst1000", "TickCount+QPC", 0, clk0, clk1, mainTid,
            "qpc_regress=" + qpcRegress + ";tick_regress=" + tickRegress);
        Console.WriteLine("clock_reads=1000");
        Console.WriteLine("qpc_regressions=" + qpcRegress);
        Console.WriteLine("tick_regressions=" + tickRegress);

        long na0 = Qpc();
        uint naRv = SleepEx(200, false);
        long na1 = Qpc();
        Ev("sleepex_nonalert", "SleepEx", 200, na0, na1, mainTid, "alertable=0;rv=" + naRv);
        Console.WriteLine("sleepex_nonalert_ms=" + ToMs(na1 - na0).ToString("0.###", Inv));
        Console.WriteLine("sleepex_nonalert_rv=" + naRv);

        Interlocked.Exchange(ref ApcRan, 0);
        uint sleepTid = 0;
        uint sleepRv = 0;
        long sx0 = 0, sx1 = 0;
        var ready = new ManualResetEvent(false);
        var sleeper = new Thread(() => {
            sleepTid = GetCurrentThreadId();
            ready.Set();
            sx0 = Qpc();
            sleepRv = SleepEx(500, true);
            sx1 = Qpc();
        });
        sleeper.Start();
        ready.WaitOne();
        Thread.Sleep(30);
        int otErr = 0, qapcErr = 0;
        uint qapcRv = 0;
        bool otOk = false;
        IntPtr h = OpenThread(THREAD_SET_CONTEXT, false, sleepTid);
        otErr = Marshal.GetLastWin32Error();
        otOk = h != IntPtr.Zero;
        Console.WriteLine("openthread_ok=" + otOk);
        Console.WriteLine("openthread_gle=" + otErr);
        if (otOk) {
            qapcRv = QueueUserAPC(KeepApc, h, UIntPtr.Zero);
            qapcErr = Marshal.GetLastWin32Error();
            CloseHandle(h);
        }
        Console.WriteLine("queueuserapc_rv=" + qapcRv);
        Console.WriteLine("queueuserapc_gle=" + qapcErr);
        sleeper.Join();
        int apcFlag = Interlocked.CompareExchange(ref ApcRan, 0, 0);
        Ev("sleepex_alert", "SleepEx", 500, sx0, sx1, sleepTid,
            "alertable=1;rv=" + sleepRv
            + ";apc_woke=" + (sleepRv == WAIT_IO_COMPLETION)
            + ";apc_callback=" + apcFlag
            + ";openthread_ok=" + otOk + ";openthread_gle=" + otErr
            + ";queueuserapc_rv=" + qapcRv + ";queueuserapc_gle=" + qapcErr);
        Console.WriteLine("sleepex_alert_ms=" + ToMs(sx1 - sx0).ToString("0.###", Inv));
        Console.WriteLine("sleepex_alert_rv=" + sleepRv);
        Console.WriteLine("sleepex_apc_woke=" + (sleepRv == WAIT_IO_COMPLETION));
        Console.WriteLine("apc_callback=" + apcFlag);

        long w0 = Qpc();
        using (var ev = new ManualResetEvent(false)) {
            ThreadPool.QueueUserWorkItem(_ => { Thread.Sleep(30); ev.Set(); });
            ev.WaitOne(500);
        }
        long w1 = Qpc();
        Ev("waitone", "WaitOne", 500, w0, w1, mainTid, "managed_early");
        Console.WriteLine("waitone_ms=" + ToMs(w1 - w0).ToString("0.###", Inv));

        Console.WriteLine("seq_ms=" + ToMs(s2 - s0).ToString("0.###", Inv));
        Console.WriteLine("par_wall_create_ms=" + ToMs(geo1 - create0).ToString("0.###", Inv));
        Console.WriteLine("par_wall_barrier_ms=" + ToMs(geo1 - geo0).ToString("0.###", Inv));
        bool model = ToMs(geo1 - geo0) < ToMs(s2 - s0) && inter > 0 && qpcRegress == 0;
        Console.WriteLine(model ? "WAIT_MODEL_OK" : "WAIT_MODEL_CHECK");
        Console.WriteLine("json_locale=invariant");
        Console.WriteLine("run_id=" + RunId);
    }
}
