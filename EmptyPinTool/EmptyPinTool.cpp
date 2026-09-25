// Empty / noop Pintool for Reviewer 2 baseline ladder (pin_empty_tool).
// Pin + instrumentation runtime WITHOUT TOMWare defensive modules.
#include "pin.H"

int main(int argc, char* argv[])
{
    if (PIN_Init(argc, argv))
        return 1;
    PIN_StartProgram();
    return 0;
}
