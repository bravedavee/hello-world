// ...existing code...

// Chart Drawing Configuration
// ...existing code...

//+------------------------------------------------------------------+
//| IPDA_Logger.mqh - Logging and debugging functions                |
//+------------------------------------------------------------------+
#ifndef __IPDA_LOGGER__
#define __IPDA_LOGGER__

#include "IPDA_ExternalFunctions.mqh"

// Log levels
enum ENUM_LOG_LEVEL {
    LOG_LEVEL_DEBUG,    // Debug messages (most verbose)
    LOG_LEVEL_INFO,     // Normal informational messages
    LOG_LEVEL_WARNING,  // Warning messages
    LOG_LEVEL_ERROR     // Error messages (most important)
};

// Global variables for logging
int g_LogHandle = INVALID_HANDLE;        // File handle for logging
string g_LogFilename = "";               // Current log filename
ENUM_LOG_LEVEL g_LogLevel = LOG_LEVEL_INFO;  // Current log level

//+------------------------------------------------------------------+
//| Initialize logging system                                        |
//+------------------------------------------------------------------+
bool InitLogger(ENUM_LOG_LEVEL level = LOG_LEVEL_INFO) {
    g_LogLevel = level;
    
    // Generate log filename based on current time
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    g_LogFilename = StringFormat("IPDA_EA_%d%02d%02d_%02d%02d%02d.log", 
                              dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
    
    // Create or open log file
    g_LogHandle = FileOpen(g_LogFilename, FILE_WRITE|FILE_ANSI|FILE_TXT);
    
    if(g_LogHandle == INVALID_HANDLE) {
        Print("Error: Unable to open log file. Error code: ", GetLastError());
        return false;
    }
    
    // Write header
    FileWrite(g_LogHandle, "=============================================");
    FileWrite(g_LogHandle, "  IPDA EA Log File - Started: ", TimeToString(TimeCurrent()));
    FileWrite(g_LogHandle, "  Symbol: ", Symbol(), " | Period: ", EnumToString((ENUM_TIMEFRAMES)Period()));
    FileWrite(g_LogHandle, "=============================================");
    FileFlush(g_LogHandle);
    
    return true;
}

//+------------------------------------------------------------------+
//| Close the logger                                                 |
//+------------------------------------------------------------------+
void CloseLogger() {
    if(g_LogHandle != INVALID_HANDLE) {
        FileWrite(g_LogHandle, "=============================================");
        FileWrite(g_LogHandle, "  IPDA EA Log File - Ended: ", TimeToString(TimeCurrent()));
        FileWrite(g_LogHandle, "=============================================");
        FileClose(g_LogHandle);
        g_LogHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Log a message with specified level                               |
//+------------------------------------------------------------------+
void LogMessage(string component, string message, ENUM_LOG_LEVEL level) {
    // Only log if the level is at or above the current log level
    if(level < g_LogLevel) return;
    
    // Format the log message
    string levelText;
    switch(level) {
        case LOG_LEVEL_DEBUG:   levelText = "DEBUG"; break;
        case LOG_LEVEL_INFO:    levelText = "INFO"; break;
        case LOG_LEVEL_WARNING: levelText = "WARNING"; break;
        case LOG_LEVEL_ERROR:   levelText = "ERROR"; break;
        default:                levelText = "UNKNOWN";
    }
    
    string formattedMessage = StringFormat("%s | %s | [%s] %s", 
                                      TimeToString(TimeCurrent(), TIME_SECONDS),
                                      levelText,
                                      component,
                                      message);
    
    // Write to log file
    if(g_LogHandle != INVALID_HANDLE) {
        FileWrite(g_LogHandle, formattedMessage);
        FileFlush(g_LogHandle);
    }
    
    // Print to journal
    Print(formattedMessage);
    
    // Show as alert for errors
    if(level == LOG_LEVEL_ERROR) {
        Alert("IPDA EA ERROR: ", message);
    }
}

//+------------------------------------------------------------------+
//| Log debug message                                                |
//+------------------------------------------------------------------+
void LogDebug(string component, string message) {
    LogMessage(component, message, LOG_LEVEL_DEBUG);
}

//+------------------------------------------------------------------+
//| Log info message                                                 |
//+------------------------------------------------------------------+
void LogInfo(string component, string message) {
    LogMessage(component, message, LOG_LEVEL_INFO);
}

//+------------------------------------------------------------------+
//| Log warning message                                              |
//+------------------------------------------------------------------+
void LogWarning(string component, string message) {
    LogMessage(component, message, LOG_LEVEL_WARNING);
}

//+------------------------------------------------------------------+
//| Log error message                                                |
//+------------------------------------------------------------------+
void LogError(string component, string message) {
    LogMessage(component, message, LOG_LEVEL_ERROR);
}

//+------------------------------------------------------------------+
//| Log trade activity                                               |
//+------------------------------------------------------------------+
void LogTrade(string action, string symbol, double price, double volume, string comment = "") {
    string message = StringFormat("%s | %s | Price: %.5f | Volume: %.2f | %s", 
                              action, symbol, price, volume, comment);
    LogInfo("TRADE", message);
}

// Note: TimeFrameCheck function has been moved to IPDA_Utility.mqh

#endif // __IPDA_LOGGER__

// ...existing code...
