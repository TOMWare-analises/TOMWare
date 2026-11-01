access_r43b_process_tree — Native + TMW0 + TMW_DO (30 Oct 2026). Complete.
Preserves access_r43 (broken process_tree.txt). DLL 4BBC6270. script_rev=r43b.2. identified=false.

Native: all EXITED STATUS_ENTRYPOINT_NOT_FOUND (-1073741511), peak_ws=0, n_tree=0.
  BEN_28 3375 ms; BEN_46 1155 ms; BEN_47 437 ms.

TMW0 (-q):
  BEN_28 EXITED -1073741511 1625 ms peak_ws=65306624; live n_tree=3 then post-mortem ?
  BEN_46 EXITED -1073741511 1625 ms peak_ws=73228288; named pin.exe -> sample + conhost
  BEN_47 EXITED -1 719 ms; Pin Win32 740 elevation; not a SkewMask hold

TMW_DO (-do -q):
  BEN_28 EXITED -1073741511 49344 ms peak_ws=79572992; n_tree=3 ~49 s then dead. Not STILL_ALIVE.
  BEN_46 STILL_ALIVE 61063 ms peak_ws=70381568; named pin.exe -> sample + conhost
  BEN_47 EXITED -1 453 ms; same Pin 740. Not window fill.

Persistence is state or wait, not application progress. Not the 9000. Not Arancino.
