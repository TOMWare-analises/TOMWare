#include "ModuleCounters.h"
#include "TomwareLog.h"
#include <fstream>
#include <sstream>

extern KNOB<BOOL> KnobModuleCounters;
extern KNOB<std::string> KnobModuleCountersFile;

static volatile bool g_enabled = false;
static PIN_LOCK g_lock;

// Estrutura de contadores agregados
struct CountersState {
    // AntiDebug
    INT32 ad_initializations = 0;
    INT32 ad_sanitizations = 0;
    INT32 ad_being_debugged_before = -1;
    INT32 ad_being_debugged_after = -1;
    UINT32 ad_ntglobalflag_before = 0;
    UINT32 ad_ntglobalflag_after = 0;
    INT32 ad_access_faults = 0;

    // ProcessEnum
    INT32 pe_calls_intercepted = 0;
    INT32 pe_processes_examined = 0;
    INT32 pe_processes_filtered = 0;
    INT32 pe_modules_examined = 0;
    INT32 pe_modules_filtered = 0;
    INT32 pe_unmodified_calls = 0;

    // SanitizePinEnvVars
    INT32 env_entries_examined = 0;
    INT32 env_pin_entries_found = 0;
    INT32 env_entries_sanitized = 0;
    INT32 env_access_faults = 0;

    // InstMemcmpMask
    INT32 mc_comparisons_intercepted = 0;
    INT32 mc_signatures_matched = 0;
    INT32 mc_responses_modified = 0;
    INT32 mc_forwarded_to_original = 0;

    // SkewMask
    INT32 sk_sleep_calls_intercepted = 0;
    INT32 sk_time_queries_intercepted = 0;
    double sk_requested_delay_ms_total = 0.0;
    double sk_observed_delay_ms_total = 0.0;
    INT64 sk_accumulated_skew_ticks = 0;
    INT32 sk_corrections_applied = 0;
    INT32 sk_regressions_detected = 0;
} g_state;

static VOID ModuleCounters_Fini(INT32 code, VOID* v) {
    if (!g_enabled) return;
    ModuleCounters_DumpJson();
}

static VOID ModuleCounters_PrepareFini(VOID* v) {
    if (!g_enabled) return;
    ModuleCounters_DumpJson();
}

static VOID ModuleCounters_OnAppStart(VOID* v) {
    if (!g_enabled) return;
    ModuleCounters_DumpJson();
}

static INT32 g_mc_since_dump = 0;

static VOID ModuleCounters_DumpAfterUpdate(bool force) {
    if (!g_enabled) return;
    if (!force) {
        g_mc_since_dump++;
        if (g_mc_since_dump < 32) return;
    }
    g_mc_since_dump = 0;
    ModuleCounters_DumpJson();
}

void ModuleCounters_Init() {
    if (KnobModuleCounters.Value()) {
        g_enabled = true;
        PIN_InitLock(&g_lock);
        PIN_AddFiniFunction(ModuleCounters_Fini, 0);
        PIN_AddPrepareForFiniFunction(ModuleCounters_PrepareFini, 0);
        PIN_AddApplicationStartFunction(ModuleCounters_OnAppStart, 0);
        ModuleCounters_DumpJson();
    }
}

bool ModuleCounters_IsEnabled() {
    return g_enabled;
}

void ModuleCounters_AntiDebug_OnInit() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.ad_initializations++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_AntiDebug_OnSanitize(int bdBefore, int bdAfter, unsigned long ntgBefore, unsigned long ntgAfter, bool fault) {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.ad_sanitizations++;
    g_state.ad_being_debugged_before = bdBefore;
    g_state.ad_being_debugged_after = bdAfter;
    g_state.ad_ntglobalflag_before = ntgBefore;
    g_state.ad_ntglobalflag_after = ntgAfter;
    if (fault) g_state.ad_access_faults++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_ProcessEnum_OnCall() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.pe_calls_intercepted++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_ProcessEnum_OnProcessExamined(bool filtered) {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.pe_processes_examined++;
    if (filtered) g_state.pe_processes_filtered++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_ProcessEnum_OnModuleExamined(bool filtered) {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.pe_modules_examined++;
    if (filtered) g_state.pe_modules_filtered++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_ProcessEnum_OnUnmodified() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.pe_unmodified_calls++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Env_OnExamined() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.env_entries_examined++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Env_OnPinFound() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.env_pin_entries_found++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Env_OnSanitized() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.env_entries_sanitized++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Env_OnFault() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.env_access_faults++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Memcmp_OnIntercept() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.mc_comparisons_intercepted++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(false);
}

void ModuleCounters_Memcmp_OnSignatureMatched() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.mc_signatures_matched++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Memcmp_OnModified() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.mc_responses_modified++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Memcmp_OnForwarded() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.mc_forwarded_to_original++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(false);
}

void ModuleCounters_Skew_OnSleep(double requestedMs, double observedMs) {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.sk_sleep_calls_intercepted++;
    g_state.sk_requested_delay_ms_total += requestedMs;
    g_state.sk_observed_delay_ms_total += observedMs;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Skew_OnTimeQuery(INT64 skewTicksApplied) {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.sk_time_queries_intercepted++;
    g_state.sk_corrections_applied++;
    g_state.sk_accumulated_skew_ticks = skewTicksApplied;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_Skew_OnRegression() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    g_state.sk_regressions_detected++;
    PIN_ReleaseLock(&g_lock);
    ModuleCounters_DumpAfterUpdate(true);
}

void ModuleCounters_DumpJson() {
    if (!g_enabled) return;
    PIN_GetLock(&g_lock, 1);
    CountersState snap = g_state;
    std::string outPath = KnobModuleCountersFile.Value();
    PIN_ReleaseLock(&g_lock);

    std::ofstream out(outPath.c_str(), std::ios::trunc);
    if (!out.is_open()) return;

    out << "{\n";
    out << "  \"schema_version\": 1,\n";
    out << "  \"counters_enabled\": true,\n";
    out << "  \"antidebug\": {\n";
    out << "    \"initializations\": " << snap.ad_initializations << ",\n";
    out << "    \"sanitizations\": " << snap.ad_sanitizations << ",\n";
    out << "    \"being_debugged_before\": " << snap.ad_being_debugged_before << ",\n";
    out << "    \"being_debugged_after\": " << snap.ad_being_debugged_after << ",\n";
    out << "    \"ntglobalflag_before\": " << snap.ad_ntglobalflag_before << ",\n";
    out << "    \"ntglobalflag_after\": " << snap.ad_ntglobalflag_after << ",\n";
    out << "    \"access_faults\": " << snap.ad_access_faults << "\n";
    out << "  },\n";
    out << "  \"process_enum\": {\n";
    out << "    \"calls_intercepted\": " << snap.pe_calls_intercepted << ",\n";
    out << "    \"processes_examined\": " << snap.pe_processes_examined << ",\n";
    out << "    \"processes_filtered\": " << snap.pe_processes_filtered << ",\n";
    out << "    \"modules_examined\": " << snap.pe_modules_examined << ",\n";
    out << "    \"modules_filtered\": " << snap.pe_modules_filtered << ",\n";
    out << "    \"unmodified_calls\": " << snap.pe_unmodified_calls << "\n";
    out << "  },\n";
    out << "  \"sanitize_env\": {\n";
    out << "    \"entries_examined\": " << snap.env_entries_examined << ",\n";
    out << "    \"pin_entries_found\": " << snap.env_pin_entries_found << ",\n";
    out << "    \"entries_sanitized\": " << snap.env_entries_sanitized << ",\n";
    out << "    \"access_faults\": " << snap.env_access_faults << "\n";
    out << "  },\n";
    out << "  \"memcmp_mask\": {\n";
    out << "    \"comparisons_intercepted\": " << snap.mc_comparisons_intercepted << ",\n";
    out << "    \"signatures_matched\": " << snap.mc_signatures_matched << ",\n";
    out << "    \"responses_modified\": " << snap.mc_responses_modified << ",\n";
    out << "    \"forwarded_to_original\": " << snap.mc_forwarded_to_original << "\n";
    out << "  },\n";
    out << "  \"skew_mask\": {\n";
    out << "    \"sleep_calls_intercepted\": " << snap.sk_sleep_calls_intercepted << ",\n";
    out << "    \"time_queries_intercepted\": " << snap.sk_time_queries_intercepted << ",\n";
    out << "    \"requested_delay_ms_total\": " << snap.sk_requested_delay_ms_total << ",\n";
    out << "    \"observed_delay_ms_total\": " << snap.sk_observed_delay_ms_total << ",\n";
    out << "    \"accumulated_skew_ticks\": " << snap.sk_accumulated_skew_ticks << ",\n";
    out << "    \"corrections_applied\": " << snap.sk_corrections_applied << ",\n";
    out << "    \"regressions_detected\": " << snap.sk_regressions_detected << "\n";
    out << "  }\n";
    out << "}\n";
    out.close();
}
