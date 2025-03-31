//+------------------------------------------------------------------+
//| IPDA_DLLImports.mqh - Centralized External DLL Functions         |
//+------------------------------------------------------------------+
#ifndef __IPDA_DLLIMPORTS__
#define __IPDA_DLLIMPORTS__

//+------------------------------------------------------------------+
//| Windows User Interface Functions                                 |
//+------------------------------------------------------------------+
#import "user32.dll"
   // MessageBox functions for displaying alerts/messages to the user
   int MessageBoxW(int hWnd, string lpText, string lpCaption, int uType);
#import

//+------------------------------------------------------------------+
//| Windows System Functions                                         |
//+------------------------------------------------------------------+
#import "kernel32.dll"
   // Get the last error code from Windows API functions
   int GetLastError(void);
#import

//+------------------------------------------------------------------+
//| Windows Shell Functions                                          |
//+------------------------------------------------------------------+
#import "shell32.dll"
   // ShellExecute for opening files or URLs with associated programs
   int ShellExecuteW(int hwnd, string lpOperation, string lpFile, 
                    string lpParameters, string lpDirectory, int nShowCmd);
#import

//+------------------------------------------------------------------+
//| Function Documentation                                           |
//+------------------------------------------------------------------+
/*
Usage Examples:

1. MessageBoxW:
   int result = MessageBoxW(0, "Trade executed successfully!", "IPDA EA Notification", 0x00000040);
   // 0x00000040 = MB_ICONINFORMATION

2. GetLastError:
   if(operation_failed) {
      int error = GetLastError();
      Print("Windows API Error: ", error);
   }
   
3. ShellExecuteW:
   ShellExecuteW(0, "open", "https://www.mql5.com/en/docs", "", "", 1);
   // Opens the MQL5 documentation in default browser
*/

#endif // __IPDA_DLLIMPORTS__
