access_r43c_process_tree — 27/27 ingested (30–31 Oct 2026).
script_rev=r43c.1  elevated=true  sample_ms=50  first_sample=0–17 ms
DLL 4BBC6270  script_sha256 D007657B1862A81A1B78C3AFC974B684D7EFE19963AECF00B1A583D86B708F0E
Pin actually invoked: pin\intel64\bin\pin.exe FBA632E4…741A (not pin\pin.exe 920A730A).
Preserves access_r43 and access_r43b. identified=false. behavioral_progress_observed=false.

Native 9/9: EXITED −1073741511 in 107–813 ms. Last tree unnamed. BEN_47 Native = same entrypoint, not Win32 740.

TMW0 9/9: EXITED −1073741511 in 938–1360 ms. Last-sample named: BEN_46 r1; BEN_47 r1/r2; BEN_28 r3 (pin+conhost).

TMW_DO:
  BEN_28 r1 41391 ms EXITED unnamed-last (named during window)
  BEN_28 r2 42516 ms EXITED named pin→sample+conhost
  BEN_28 r3 45688 ms EXITED named pin→sample+conhost
  BEN_46 r1 59094 ms EXITED unnamed-last (named during window)
  BEN_46 r2 47375 ms EXITED unnamed-last (named during window)
  BEN_46 r3 53453 ms EXITED unnamed-last (named during window)
  BEN_47 r1 60062 ms STILL_ALIVE named pin→sample+conhost
  BEN_47 r2 58062 ms EXITED unnamed-last (named during window)
  BEN_47 r3 59328 ms EXITED unnamed-last (named during window)
Only 1/9 TMW_DO filled the 60 s window. 8/9 died with STATUS_ENTRYPOINT_NOT_FOUND after 41–59 s.
Last-sample unnamed is not “no tree”: process_events.jsonl has pin.exe + PE while alive.
Persistence is not application progress. Not the 9000. Not Arancino.
