#include "IPDA_DLLImports.mqh"

// Ensure DLL imports are included at the top for proper recognition

//+------------------------------------------------------------------+
//| IPDA_ExternalFunctions.mqh - Centralized External DLL Functions  |
//+------------------------------------------------------------------+
#ifndef __IPDA_EXTERNALFUNCTIONS__
#define __IPDA_EXTERNALFUNCTIONS__

// Include the centralized DLL imports
#include "IPDA_DLLImports.mqh"

// Ensure DLL imports are available for external functions

//+------------------------------------------------------------------+
//| Special Character Handling Reference                             |
//+------------------------------------------------------------------+
/*
In MQL5, ampersand (&) characters have special meaning in different contexts:

1. As a reference modifier for parameters:
   void Function(int &parameter); // Pass by reference - correct MQL5 syntax

2. In tooltip text:
   The ampersand is treated as a special character that doesn't display.
   To display a literal "&" in tooltips, use "&&":
   
   INCORRECT: ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, "A & B");
              // This will display as "A B" without the ampersand
              
   CORRECT:   ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, "A && B");
              // This will display as "A & B" with the ampersand
              
   Alternative: Use the EscapeTooltipText() utility function from IPDA_Utility.mqh

3. In string literals (normal usage):
   For regular string operations, & is treated as a normal character
   and requires no special handling.
*/

// Example wrapper function for Windows MessageBox
void ShowMessageBox(string message, string title, int type = 0) {
    // Use global namespace for imported function
    ::MessageBoxW(0, message, title, type);
}

// ✅ Example of properly accessing external DLL functions
void DemoExternalFunctions() {
    // Calling Windows API with proper namespace
    int error = ::GetLastError();
    int result = ::MessageBoxW(0, "Message", "Title", 0);
    ::ShellExecuteW(0, "open", "notepad.exe", "", "", 1);
}

#endif // __IPDA_EXTERNALFUNCTIONS__
