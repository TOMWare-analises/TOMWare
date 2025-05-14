#include "pin.H"
#include <iostream>
#include <string>
#include "Instrumentation.h"


INT32 Usage()
{
    std::cerr << "Esta ferramenta PIN fornece informa��o sobre poss�veis comportamentos evasivos (antian�lise) presentes em execut�veis\n"
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
