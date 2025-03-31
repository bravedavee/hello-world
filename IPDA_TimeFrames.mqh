//+------------------------------------------------------------------+
//| IPDA_TimeFrames.mqh - Centralized timeframe definitions          |
//+------------------------------------------------------------------+
#ifndef __IPDA_TIMEFRAMES__
#define __IPDA_TIMEFRAMES__

#include <IPDA_DLLImports.mqh>

//+------------------------------------------------------------------+
//| ENUM_LTF_TIMEFRAMES                                              |
//| Description: Custom timeframe enum used throughout IPDA modules  |
//| Usage: Used as a consistent way to represent timeframes across   |
//|        the trading system, with values matching minutes in period|
//+------------------------------------------------------------------+
enum ENUM_LTF_TIMEFRAMES {
   LTF_M1  = 1,   LTF_M5  = 5,   LTF_M15 = 15,   LTF_M30 = 30,   LTF_H1  = 60,   LTF_H4  = 240,   LTF_D1  = 1440
};

//+------------------------------------------------------------------+
//| Convert LTF enum to standard TimeFrame value                     |
//| INPUT:  ltfValue - ENUM_LTF_TIMEFRAMES value to convert          |
//| OUTPUT: Corresponding ENUM_TIMEFRAMES value from standard MQL5   |
//| NOTE:   Returns PERIOD_M15 if input doesn't match any valid case |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES ConvertLTFToTimeframe(ENUM_LTF_TIMEFRAMES ltfValue) {
    switch(ltfValue) {
        case LTF_M1:  return PERIOD_M1;
        case LTF_M5:  return PERIOD_M5;
        case LTF_M15: return PERIOD_M15;
        case LTF_M30: return PERIOD_M30;
        case LTF_H1:  return PERIOD_H1;
        case LTF_H4:  return PERIOD_H4;
        case LTF_D1:  return PERIOD_D1;
        default:      return PERIOD_M15;  // Default to M15 if no match
    }
}

//+------------------------------------------------------------------+
//| Convert standard PERIOD_ constants to ENUM_LTF_TIMEFRAMES        |
//| INPUT:  timeframe - Standard MQL5 ENUM_TIMEFRAMES value          |
//| OUTPUT: Corresponding ENUM_LTF_TIMEFRAMES custom value           |
//| NOTE:   Returns LTF_M15 if input doesn't match any valid case    |
//|         Only handles M1-D1 timeframes, not W1 or MN1             |
//+------------------------------------------------------------------+
ENUM_LTF_TIMEFRAMES StandardToLTFTimeframe(ENUM_TIMEFRAMES timeframe) {
    switch(timeframe) {
        case PERIOD_M1:  return LTF_M1;
        case PERIOD_M5:  return LTF_M5;
        case PERIOD_M15: return LTF_M15;
        case PERIOD_M30: return LTF_M30;
        case PERIOD_H1:  return LTF_H1;
        case PERIOD_H4:  return LTF_H4;
        case PERIOD_D1:  return LTF_D1;
        default:         return LTF_M15;  // Default to M15 if no match
    }
}

//+------------------------------------------------------------------+
//| Get period in seconds for a timeframe                            |
//| INPUT:  timeframe - Standard MQL5 ENUM_TIMEFRAMES value          |
//| OUTPUT: Number of seconds in the specified timeframe period      |
//| NOTE:   Wrapper around built-in PeriodSeconds() function         |
//+------------------------------------------------------------------+
int GetTimeframeSeconds(ENUM_TIMEFRAMES timeframe) {
    return PeriodSeconds(timeframe);
}

//+------------------------------------------------------------------+
//| Get period in seconds for an LTF timeframe                       |
//| INPUT:  ltf - Custom ENUM_LTF_TIMEFRAMES value                   |
//| OUTPUT: Number of seconds in the specified timeframe period      |
//| NOTE:   Converts LTF enum to standard enum then gets seconds     |
//+------------------------------------------------------------------+
int GetLTFTimeframeSeconds(ENUM_LTF_TIMEFRAMES ltf) {
    return PeriodSeconds(ConvertLTFToTimeframe(ltf));
}

//+------------------------------------------------------------------+
//| Helper function to get a timeframe name                          |
//| INPUT:  timeframe - Standard MQL5 ENUM_TIMEFRAMES value          |
//| OUTPUT: String representation (e.g., "M1", "H4") of timeframe    |
//| NOTE:   Handles all standard timeframes including W1 and MN1     |
//+------------------------------------------------------------------+
string GetTimeframeName(ENUM_TIMEFRAMES timeframe) {
    switch(timeframe) {
        case PERIOD_M1:  return "M1";
        case PERIOD_M2:  return "M2";
        case PERIOD_M3:  return "M3";
        case PERIOD_M4:  return "M4";
        case PERIOD_M5:  return "M5";
        case PERIOD_M6:  return "M6";
        case PERIOD_M10: return "M10";
        case PERIOD_M12: return "M12";
        case PERIOD_M15: return "M15";
        case PERIOD_M20: return "M20";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H2:  return "H2";
        case PERIOD_H3:  return "H3";
        case PERIOD_H4:  return "H4";
        case PERIOD_H6:  return "H6";
        case PERIOD_H8:  return "H8";
        case PERIOD_H12: return "H12";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default:         return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Get timeframe from string representation                          |
//| INPUT:  tfString - String representation of timeframe (e.g. "M15")|
//| OUTPUT: ENUM_TIMEFRAMES value corresponding to the string         |
//| NOTE:   Returns PERIOD_CURRENT if no match found                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetTimeframeFromString(string tfString) {
    if (tfString == "M1")  return PERIOD_M1;
    if (tfString == "M5")  return PERIOD_M5;
    if (tfString == "M15") return PERIOD_M15;
    if (tfString == "M30") return PERIOD_M30;
    if (tfString == "H1")  return PERIOD_H1;
    if (tfString == "H4")  return PERIOD_H4;
    if (tfString == "D1")  return PERIOD_D1;
    if (tfString == "W1")  return PERIOD_W1;
    if (tfString == "MN1") return PERIOD_MN1;
    
    return PERIOD_CURRENT; // Default
}

//+------------------------------------------------------------------+
//| Convert timeframe enum value to readable string                  |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe) {
    switch(timeframe) {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default:         return "Unknown(" + IntegerToString(timeframe) + ")";
    }
}

#endif // __IPDA_TIMEFRAMES__
