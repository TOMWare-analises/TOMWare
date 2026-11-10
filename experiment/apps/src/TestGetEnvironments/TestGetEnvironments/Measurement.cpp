#include "Measurement.h"

void testGetTickCountConsistency(int numCalls, const std::function<void()>& preHook, const std::wstring& logFile)
{
    if (numCalls <= 1) {
        std::cerr << "numCalls deve ser > 1 para calcular diferencas.\n";
        return;
    }

    // ---------- 1) Coleta ------------------------------------
    std::vector<DWORD> tickValues;
    tickValues.reserve(numCalls);

    for (int i = 0; i < numCalls; ++i) {
        if (preHook) preHook();
        tickValues.push_back(GetTickCount());
    }

    // ---------- 2) Intervalos --------------------------------
    std::vector<DWORD> diff;
    diff.reserve(numCalls - 1);
    for (size_t i = 1; i < tickValues.size(); ++i)
        diff.push_back(tickValues[i] - tickValues[i - 1]);

    // ---------- 3) Estatísticas ------------------------------
    auto minmax = std::minmax_element(diff.begin(), diff.end());
    auto minIt = minmax.first;
    auto maxIt = minmax.second;

    double mean = std::accumulate(diff.begin(), diff.end(), 0.0) / diff.size();

    double var = 0.0;
    for (DWORD d : diff) {
        double delta = static_cast<double>(d) - mean;
        var += delta * delta;
    }
    var /= (diff.size() - 1);               // variância amostral
    double stddev = std::sqrt(var);

    bool consistent = std::all_of(diff.begin(), diff.end(),
        [&](DWORD d) { return d == diff.front(); });

    // ---------- 4) Saída na tela ------------------------------
    auto printVec = [](const std::vector<DWORD>& v) {
        for (size_t i = 0; i < v.size(); ++i)
            std::cout << '[' << i << "] " << v[i] << '\n';
        };

    std::cout << "Valores de GetTickCount (ms):\n";   printVec(tickValues);
    std::cout << "\nIntervalos (ms):\n";              printVec(diff);

    std::cout << "\nAs chamadas a GetTickCount "
        << (consistent ? "tem" : "Nao tem")
        << " intervalo constante.\n";

    std::cout << std::fixed << std::setprecision(2)
        << "\n--- Estatisticas (ms) ---\n"
        << "N amostras : " << diff.size() << '\n'
        << "Media      : " << mean << '\n'
        << "Variancia  : " << var << '\n'
        << "Desv. pad. : " << stddev << '\n'
        << "Min        : " << *minIt << '\n'
        << "Max        : " << *maxIt << "\n\n";

    // ---------- 5) Grava no log -------------------------------
    std::wofstream log(logFile, std::ios::app);
    if (!log) {
        std::wcerr << L"Falha ao abrir arquivo de log: " << logFile << L'\n';
        return;
    }

    // Timestamp legível
    auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
    std::tm tmNow{};
    localtime_s(&tmNow, &now);   // dest, src

    log << L"\n=== Execucao em " << std::put_time(&tmNow, L"%Y-%m-%d %H:%M:%S") << L" ===\n";

    log << L"numCalls = " << numCalls << L", consistent = " << (consistent ? L"true" : L"false") << L"\n";

    log << L"Valores GetTickCount (ms): ";
    for (DWORD v : tickValues) log << v << L' ';
    log << L'\n';

    log << L"Intervalos (ms): ";
    for (DWORD d : diff)       log << d << L' ';
    log << L'\n';

    log << std::fixed << std::setprecision(2)
        << L"Media=" << mean << L", Var=" << var
        << L", SD=" << stddev << L", Min=" << *minIt << L", Max=" << *maxIt << L"\n";
}

