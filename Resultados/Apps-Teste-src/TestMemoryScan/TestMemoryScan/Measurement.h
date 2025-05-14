#pragma once

#include <windows.h>
#include <vector>
#include <iostream>
#include <iomanip>
#include <numeric>
#include <algorithm>
#include <cmath>
#include <fstream>
#include <chrono>
#include <ctime>
#include <functional>

void testGetTickCountConsistency(int numCalls, const std::function<void()>& preHook, const std::wstring& logFile);