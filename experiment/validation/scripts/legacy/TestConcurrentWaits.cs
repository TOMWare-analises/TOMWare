using System;
using System.Diagnostics;
using System.Threading;

class TestConcurrentWaits {
    static void Main() {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        const int sleepMs = 200;

        var swSeq = Stopwatch.StartNew();
        Thread.Sleep(sleepMs);
        Thread.Sleep(sleepMs);
        swSeq.Stop();

        var swPar = Stopwatch.StartNew();
        var t1 = new Thread(() => Thread.Sleep(sleepMs));
        var t2 = new Thread(() => Thread.Sleep(sleepMs));
        t1.Start(); t2.Start();
        t1.Join(); t2.Join();
        swPar.Stop();

        var swRep = Stopwatch.StartNew();
        long a = Environment.TickCount;
        Thread.Sleep(50);
        long b = Environment.TickCount;
        swRep.Stop();
        long delta = b - a;
        bool monotonic = delta >= 0;

        var swAlert = Stopwatch.StartNew();
        using (var ev = new ManualResetEvent(false)) {
            ThreadPool.QueueUserWorkItem(_ => { Thread.Sleep(30); ev.Set(); });
            ev.WaitOne(500);
        }
        swAlert.Stop();

        Console.WriteLine("seq_ms=" + swSeq.ElapsedMilliseconds);
        Console.WriteLine("par_ms=" + swPar.ElapsedMilliseconds);
        Console.WriteLine("tick_delta_ms=" + delta);
        Console.WriteLine("monotonic=" + monotonic);
        Console.WriteLine("alertable_ms=" + swAlert.ElapsedMilliseconds);
        bool overlapOk = swPar.ElapsedMilliseconds < swSeq.ElapsedMilliseconds;
        bool noBackward = monotonic;
        Console.WriteLine(overlapOk && noBackward ? "WAIT_MODEL_OK" : "WAIT_MODEL_CHECK");
    }
}
