#include "pin.H"
#include <iostream>
#include <string>
#include "Instrumentation.h"


INT32 Usage()
{
    std::cerr << "This Pin tool provides countermeasures for evasive (anti-analysis) behaviors in executables\n"
        "\n";
    std::cerr << KNOB_BASE::StringKnobSummary();
    std::cerr << std::endl;
    return -1;
}

int main(int argc, char* argv[]) {
    
    WindowsAPI::SetConsoleOutputCP(CP_UTF8);

    if (PIN_Init(argc, argv))
    {
        return Usage();
    }

    InitInstrumentation();

    return 0;
}
