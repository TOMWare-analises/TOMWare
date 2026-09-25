// FidelityProbe — lightweight Pin tool for R2-6 behavioral fidelity.
// Collects: BBL coverage proxy, image-load count, watched-API hit counts.
// Output: text file via -o <path> (default fidelity.out)
#include "pin.H"
#include <fstream>
#include <string>

using std::endl;
using std::ofstream;
using std::string;

static ofstream OutFile;
static UINT64 bblCount = 0;
static UINT64 imgCount = 0;

enum ApiId
{
    API_IsDebuggerPresent = 0,
    API_CheckRemoteDebuggerPresent,
    API_NtQueryInformationProcess,
    API_GetTickCount,
    API_GetTickCount64,
    API_QueryPerformanceCounter,
    API_Sleep,
    API_CreateFileW,
    API_CreateFileA,
    API_VirtualAlloc,
    API_VirtualProtect,
    API_CreateProcessW,
    API_CreateToolhelp32Snapshot,
    API_EnumProcesses,
    API_GetEnvironmentVariableW,
    API_COUNT
};

static const char* ApiNames[API_COUNT] = {
    "IsDebuggerPresent",
    "CheckRemoteDebuggerPresent",
    "NtQueryInformationProcess",
    "GetTickCount",
    "GetTickCount64",
    "QueryPerformanceCounter",
    "Sleep",
    "CreateFileW",
    "CreateFileA",
    "VirtualAlloc",
    "VirtualProtect",
    "CreateProcessW",
    "CreateToolhelp32Snapshot",
    "EnumProcesses",
    "GetEnvironmentVariableW"
};

static UINT64 apiHits[API_COUNT];

KNOB<string> KnobOutputFile(KNOB_MODE_WRITEONCE, "pintool", "o", "fidelity.out",
                            "output file for fidelity counters");

VOID CountBbl() { bblCount++; }

VOID OnApi(UINT32 id)
{
    if (id < (UINT32)API_COUNT)
        apiHits[id]++;
}

VOID Trace(TRACE trace, VOID* v)
{
    for (BBL bbl = TRACE_BblHead(trace); BBL_Valid(bbl); bbl = BBL_Next(bbl))
    {
        BBL_InsertCall(bbl, IPOINT_BEFORE, (AFUNPTR)CountBbl, IARG_END);
    }
}

VOID ImageLoad(IMG img, VOID* v)
{
    imgCount++;
    for (int i = 0; i < API_COUNT; i++)
    {
        RTN rtn = RTN_FindByName(img, ApiNames[i]);
        if (RTN_Valid(rtn))
        {
            RTN_Open(rtn);
            RTN_InsertCall(rtn, IPOINT_BEFORE, (AFUNPTR)OnApi, IARG_UINT32, (UINT32)i, IARG_END);
            RTN_Close(rtn);
        }
    }
}

VOID Fini(INT32 code, VOID* v)
{
    OutFile.setf(std::ios::showbase);
    OutFile << "bbl_count " << bblCount << endl;
    OutFile << "img_count " << imgCount << endl;
    for (int i = 0; i < API_COUNT; i++)
    {
        OutFile << "api_" << ApiNames[i] << " " << apiHits[i] << endl;
    }
    OutFile.close();
}

int main(int argc, char* argv[])
{
    if (PIN_Init(argc, argv))
        return 1;
    for (int i = 0; i < API_COUNT; i++)
        apiHits[i] = 0;
    OutFile.open(KnobOutputFile.Value().c_str());
    TRACE_AddInstrumentFunction(Trace, 0);
    IMG_AddInstrumentFunction(ImageLoad, 0);
    PIN_AddFiniFunction(Fini, 0);
    PIN_StartProgram();
    return 0;
}
