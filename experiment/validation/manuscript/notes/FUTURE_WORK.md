# �VIII � future work (colar no Overleaf)

Strike from the current list: item 4 (combined `-da`), item 5 (NAT / empty pintool / TMW0), and the �expand the corpus + confidence intervals� half of item 7. Those are in this revision, together with the fixed-N=30 timing oracle and the matched AntiDebug 3+3 evaluation.

## English (paste)

Following the present 100-binary / nine-condition campaign, future work will:

1) extend AntiDebug to additional debugging mechanisms and information classes exposed through `NtQueryInformationProcess`;
2) extend ProcessEnum to native queries such as `NtQuerySystemInformation` and other process- and module-enumeration interfaces;
3) handle direct `RDTSC` and `RDTSCP` reads and investigate consistency across intercepted and non-intercepted timing sources;
4) compare control flows, system calls, code coverage, and external effects between baseline and countermeasure-enabled executions beyond the external observer used here (exit code, stdout hash, child processes, and new files);
5) compile TOMWare.M for Win32 and evaluate the five oracles, then an optional 32-bit PE corpus, under the Pin 3.28 `ia32` runtime already present in the kit (the current corpus is 100/100 x64 and cannot be instrumented by that runtime);
6) perform an experimental comparison with Arancino [4] on a **shared 32-bit protocol** (the published Pin 2.14 + Visual Studio 2010 toolchain, or a documented port), without treating a Pin-generation or ISA mismatch as a ranking;
7) implement and compare functionally equivalent countermeasures in other instrumentation environments when their architectures permit meaningful correspondence.

The 9,000-run x64 / Pin 3.28 campaign does not constitute item 6.

## Portugues (referencia interna)

1) AntiDebug alem de BeingDebugged/NtGlobalFlag.
2) ProcessEnum em NtQuerySystemInformation.
3) RDTSC/RDTSCP.
4) Fidelidade por traces (a Etapa 6 so observou exit/stdout/filhos/ficheiros).
5) 32-bit: DLL Win32 + Pin 3.28 ia32; oraculos; corpus 32-bit opcional.
6) Bake-off Arancino em protocolo 32-bit partilhado (Pin 2.14+VS2010 ou porto documentado).
7) Outros ambientes de instrumentacao.

Nao afirmar superioridade ate o item 6 existir.
