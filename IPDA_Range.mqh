//+------------------------------------------------------------------+
//| IPDA_Range.mqh - Range detection and visualization for IPDA       |
//+------------------------------------------------------------------+
#ifndef __IPDA_RANGE__
#define __IPDA_RANGE__

// Proper include order - use quotes for local files, not angle brackets
#include "IPDA_DLLImports.mqh"
#include "IPDA_Globals.mqh"
#include "IPDA_Logger.mqh"
#include "IPDA_Sweep.mqh"
#include "IPDA_Utility.mqh"  // Include this to use shared utility functions
#include <Trade/Trade.mqh>   // Angle brackets for standard library files
#include <ChartObjects/ChartObjectsTxtControls.mqh>

//+------------------------------------------------------------------+
//| Sweep Type Enumeration                                           |
//+------------------------------------------------------------------+
enum ENUM_SWEEP_TYPE {
    SWEEP_HIGH = 0,  // High price sweep
    SWEEP_LOW = 1,   // Low price sweep
    SWEEP_BOTH = 2   // Both directions sweep
};

// Utility functions for range detection
double GetRangeHigh(string symbol, ENUM_TIMEFRAMES timeframe, int depth = 6);
double GetRangeLow(string symbol, ENUM_TIMEFRAMES timeframe, int depth = 6);
datetime IdentifyRangeStartCandle(string symbol, ENUM_TIMEFRAMES timeframe);

// Sweep detection functions
bool IsSweepDetected(string symbol, ENUM_TIMEFRAMES timeframe, double level, ENUM_SWEEP_TYPE type);
void VisualizeSweep(string symbol, double level, ENUM_SWEEP_TYPE type);

// Zone management functions
void AssignRangeZone(ElementZone &zone, string name, double top, double bottom, datetime startTime);
void VisualizeRangeElement(string symbol, ElementZone &zone, color clr);

// IPDA Range calculation and visualization
bool CalculateIPDARange(string symbol, ENUM_TIMEFRAMES timeframe);
void VisualizeIPDAZones(string symbol);

bool IsCurrentlySweepingLevel(string symbol, double level, ENUM_SWEEP_TYPE sweepType);
bool WasPriceAbove(string symbol, double level, int candles);
bool WasPriceBelow(string symbol, double level, int candles);
bool DetectMidpointConfirmation(string symbol, ENUM_TIMEFRAMES tf);

//+------------------------------------------------------------------+
//| Assign values to a range zone structure                          |
//+------------------------------------------------------------------+
void AssignRangeZone(ElementZone &zone, string name, double top, double bottom, datetime startTime) {
    zone.Name = name;
    zone.PriceTop = top;
    zone.PriceBottom = bottom;
    zone.TimeStart = startTime;
    zone.TimeEnd = startTime + ::PeriodSeconds(PERIOD_CURRENT) * 10;
    zone.MitigationLevel = 0.0;
    zone.IsInvalidated = false;
    
    // Also assign to alternative field names for compatibility
    zone.upper = top;
    zone.lower = bottom;
    zone.time = startTime;
    zone.label = name;
    zone.isActive = true;
    
    // Set default color based on zone type
    if (StringFind(name, "Range") >= 0) {
        zone.zoneColor = clrDarkSlateGray;
        zone.type = 4; // Range Zone
    } else {
        zone.zoneColor = clrGray;
        zone.type = 0; // Other
    }
    
    LogInfo("RANGE", StringFormat("Created range zone '%s' [%.5f - %.5f]", name, top, bottom));
}

//+------------------------------------------------------------------+
//| Visualize a range element on the chart                           |
//+------------------------------------------------------------------+
void VisualizeRangeElement(string symbol, ElementZone &zone, color clr) {
    string objectName = zone.Name + "_" + symbol;
    
    // Use global namespace operator consistently
    if (!::ObjectFind(0, objectName)) {
        ::ObjectCreate(0, objectName, OBJ_RECTANGLE, 0, zone.TimeStart, zone.PriceTop, 
                     (datetime)::TimeCurrent(), zone.PriceBottom);
        ::ObjectSetInteger(0, objectName, OBJPROP_COLOR, zone.IsInvalidated ? clrGray : clr);
        ::ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
        ::ObjectSetInteger(0, objectName, OBJPROP_RAY_RIGHT, true);
    }
}

//+------------------------------------------------------------------+
//| Calculate IPDA Range based on price action                       |
//+------------------------------------------------------------------+
bool CalculateIPDARange(string symbol, ENUM_TIMEFRAMES timeframe) {
    LogInfo(symbol, "CalculateIPDARange: Starting range calculation");
    
    // Get necessary price data
    double high[], low[], close[], open[];
    
    // Use proper global namespace operator for all MQL5 built-in functions
    if(::CopyHigh(symbol, timeframe, 0, 20, high) < 20 ||
       ::CopyLow(symbol, timeframe, 0, 20, low) < 20 ||
       ::CopyClose(symbol, timeframe, 0, 20, close) < 20 ||
       ::CopyOpen(symbol, timeframe, 0, 20, open) < 20) {
        LogError(symbol, "Failed to retrieve price data for range calculation");
        return false;
    }
    
    // Find recent high and low
    double recentHigh = high[::ArrayMaximum(high, 0, 10)];
    double recentLow = low[::ArrayMinimum(low, 0, 10)];
    
    // Find the consolidation range
    double consolidationHigh = 0.0, consolidationLow = 0.0;
    int consolidationCount = 0;
    
    // Look for consistent highs and lows to form a range
    for(int i = 1; i < 15; i++) {
        if(high[i] > high[i-1] && high[i] > high[i+1] && 
           (consolidationHigh == 0.0 || high[i] > consolidationHigh * 0.99)) {
            consolidationHigh = high[i];
            consolidationCount++;
        }
        
        if(low[i] < low[i-1] && low[i] < low[i+1] && 
           (consolidationLow == 0.0 || low[i] < consolidationLow * 1.01)) {
            consolidationLow = low[i];
            consolidationCount++;
        }
    }
    
    // If we couldn't find a clear consolidation range, use the recent high/low
    if(consolidationCount < 3 || consolidationHigh == 0.0 || consolidationLow == 0.0) {
        consolidationHigh = recentHigh;
        consolidationLow = recentLow;
    }
    
    // Calculate range details
    g_IPDARange.High = consolidationHigh;
    g_IPDARange.Low = consolidationLow;
    g_IPDARange.Mid = (consolidationHigh + consolidationLow) / 2.0;
    g_IPDARange.Range75 = consolidationLow + (consolidationHigh - consolidationLow) * 0.75;
    g_IPDARange.Range25 = consolidationLow + (consolidationHigh - consolidationLow) * 0.25;
    g_IPDARange.HighSwept = false;
    g_IPDARange.LowSwept = false;
    g_IPDARange.MidSwept = false;
    
    // Assign to more easily accessible global variables
    g_HTFRangeHigh = g_IPDARange.High;
    g_HTFRange75 = g_IPDARange.Range75;
    g_HTFRangeMid = g_IPDARange.Mid;
    g_HTFRange25 = g_IPDARange.Range25;
    g_HTFRangeLow = g_IPDARange.Low;
    
    // Log range details
    LogInfo(symbol, StringFormat("IPDA Range: High=%.5f, 75%%=%.5f, Mid=%.5f, 25%%=%.5f, Low=%.5f",
                                g_IPDARange.High, g_IPDARange.Range75, g_IPDARange.Mid, 
                                g_IPDARange.Range25, g_IPDARange.Low));
    
    LogInfo(symbol, "CalculateIPDARange: Range calculation complete");
    return true;
}

//+------------------------------------------------------------------+
//| Find the highest price in a lookback period                      |
//+------------------------------------------------------------------+
double GetRangeHigh(string symbol, ENUM_TIMEFRAMES timeframe, int depth) {
    double highestPrice = 0.0;
    
    // Find the highest high in the lookback period
    for (int i = 1; i <= depth; i++) {
        double high = ::iHigh(symbol, timeframe, i);
        if (high > highestPrice || i == 1) {
            highestPrice = high;
        }
    }
    
    return highestPrice;
}

//+------------------------------------------------------------------+
//| Find the lowest price in a lookback period                       |
//+------------------------------------------------------------------+
double GetRangeLow(string symbol, ENUM_TIMEFRAMES timeframe, int depth) {
    double lowestPrice = 0.0;
    
    // Find the lowest low in the lookback period
    for (int i = 1; i <= depth; i++) {
        double low = ::iLow(symbol, timeframe, i);
        if (low < lowestPrice || i == 1) {
            lowestPrice = low;
        }
    }
    
    return lowestPrice;
}

//+------------------------------------------------------------------+
//| Identify the candle where the range likely started               |
//+------------------------------------------------------------------+
datetime IdentifyRangeStartCandle(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Look for potential range start - significant reversal candle
    for (int i = 5; i <= 20; i++) {
        double open = ::iOpen(symbol, timeframe, i);
        double close = ::iClose(symbol, timeframe, i);
        double high = ::iHigh(symbol, timeframe, i);
        double low = ::iLow(symbol, timeframe, i);
        
        // Calculate body and total candle size
        double body = ::MathAbs(close - open);
        double totalSize = high - low;
        
        // If body is at least 60% of the candle, potential reversal candle
        if (body > 0 && totalSize > 0 && (body / totalSize) >= 0.6) {
            // For next 3 candles, check if price respects this as boundary
            bool respectedAsRange = true;
            
            for (int j = i-1; j >= i-3 && j > 0; j--) {
                double checkHigh = ::iHigh(symbol, timeframe, j);
                double checkLow = ::iLow(symbol, timeframe, j);
                
                // If bullish reversal candle, price should stay above its low
                if (close > open && checkLow < low) {
                    respectedAsRange = false;
                    break;
                }
                // If bearish reversal candle, price should stay below its high
                else if (close < open && checkHigh > high) {
                    respectedAsRange = false;
                    break;
                }
            }
            
            if (respectedAsRange) {
                return ::iTime(symbol, timeframe, i);
            }
        }
    }
    
    // Default to 10 periods ago if no clear range start found
    return ::iTime(symbol, timeframe, 10);
}

//+------------------------------------------------------------------+
//| Visualize the IPDA range zones on the chart                      |
//+------------------------------------------------------------------+
void VisualizeIPDAZones(string symbol) {
    // Use the CleanIPDAZones from IPDA_Utility.mqh instead of redefining it here
    // This avoids the duplicate function definition error
    ::CleanIPDAZones(symbol);
    
    // Get current time and calculate start/end times
    datetime currentTime = ::TimeCurrent();
    datetime startTime = currentTime - ::PeriodSeconds(PERIOD_D1) * 5; // 5 days back
    datetime endTime = currentTime + ::PeriodSeconds(PERIOD_D1) * 5;   // 5 days forward
    
    // Create rectangle for the entire range
    string zoneName = "IPDA_Zone_MainRange_" + symbol;
    if(!::ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, startTime, g_IPDARange.High, endTime, g_IPDARange.Low)) {
        LogError(symbol, "Failed to create main range visualization");
    } else {
        ::ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clrDarkSlateGray);
        ::ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
        ::ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
        ::ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
        ::ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
        ::ObjectSetInteger(0, zoneName, OBJPROP_SELECTED, false);
        ::ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);
    }
    
    // Create a line for the high boundary
    string highName = "IPDA_Zone_High_" + symbol;
    if(!::ObjectCreate(0, highName, OBJ_TREND, 0, startTime, g_IPDARange.High, endTime, g_IPDARange.High)) {
        LogError(symbol, "Failed to create high line visualization");
    } else {
        ::ObjectSetInteger(0, highName, OBJPROP_COLOR, clrRed);
        ::ObjectSetInteger(0, highName, OBJPROP_WIDTH, 2);
        ::ObjectSetInteger(0, highName, OBJPROP_STYLE, STYLE_SOLID);
        ::ObjectSetInteger(0, highName, OBJPROP_RAY_RIGHT, true);
    }
    
    // Create a line for the 75% level
    string level75Name = "IPDA_Zone_75_" + symbol;
    if(!::ObjectCreate(0, level75Name, OBJ_TREND, 0, startTime, g_IPDARange.Range75, endTime, g_IPDARange.Range75)) {
        LogError(symbol, "Failed to create 75% line visualization");
    } else {
        ::ObjectSetInteger(0, level75Name, OBJPROP_COLOR, clrDarkOrange);
        ::ObjectSetInteger(0, level75Name, OBJPROP_WIDTH, 1);
        ::ObjectSetInteger(0, level75Name, OBJPROP_STYLE, STYLE_DASH);
        ::ObjectSetInteger(0, level75Name, OBJPROP_RAY_RIGHT, true);
    }
    
    // Create a line for the mid level
    string midName = "IPDA_Zone_Mid_" + symbol;
    if(!::ObjectCreate(0, midName, OBJ_TREND, 0, startTime, g_IPDARange.Mid, endTime, g_IPDARange.Mid)) {
        LogError(symbol, "Failed to create mid line visualization");
    } else {
        ::ObjectSetInteger(0, midName, OBJPROP_COLOR, clrWhite);
        ::ObjectSetInteger(0, midName, OBJPROP_WIDTH, 1);
        ::ObjectSetInteger(0, midName, OBJPROP_STYLE, STYLE_SOLID);
        ::ObjectSetInteger(0, midName, OBJPROP_RAY_RIGHT, true);
    }
    
    // Create a line for the 25% level
    string level25Name = "IPDA_Zone_25_" + symbol;
    if(!::ObjectCreate(0, level25Name, OBJ_TREND, 0, startTime, g_IPDARange.Range25, endTime, g_IPDARange.Range25)) {
        LogError(symbol, "Failed to create 25% line visualization");
    } else {
        ::ObjectSetInteger(0, level25Name, OBJPROP_COLOR, clrDarkOrange);
        ::ObjectSetInteger(0, level25Name, OBJPROP_WIDTH, 1);
        ::ObjectSetInteger(0, level25Name, OBJPROP_STYLE, STYLE_DASH);
        ::ObjectSetInteger(0, level25Name, OBJPROP_RAY_RIGHT, true);
    }
    
    // Create a line for the low boundary
    string lowName = "IPDA_Zone_Low_" + symbol;
    if(!::ObjectCreate(0, lowName, OBJ_TREND, 0, startTime, g_IPDARange.Low, endTime, g_IPDARange.Low)) {
        LogError(symbol, "Failed to create low line visualization");
    } else {
        ::ObjectSetInteger(0, lowName, OBJPROP_COLOR, clrGreen);
        ::ObjectSetInteger(0, lowName, OBJPROP_WIDTH, 2);
        ::ObjectSetInteger(0, lowName, OBJPROP_STYLE, STYLE_SOLID);
        ::ObjectSetInteger(0, lowName, OBJPROP_RAY_RIGHT, true);
    }
    
    // Create text labels for the levels
    datetime labelTime = currentTime - ::PeriodSeconds(PERIOD_D1) * 3; // Position labels 3 days back
    
    // High label
    string highLabelName = "IPDA_Zone_HighLabel_" + symbol;
    if(!::ObjectCreate(0, highLabelName, OBJ_TEXT, 0, labelTime, g_IPDARange.High)) {
        LogError(symbol, "Failed to create high label");
    } else {
        ::ObjectSetString(0, highLabelName, OBJPROP_TEXT, "Range High");
        ::ObjectSetString(0, highLabelName, OBJPROP_FONT, "Arial");
        ::ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 8);
        ::ObjectSetInteger(0, highLabelName, OBJPROP_COLOR, clrRed);
    }
    
    // 75% label
    string label75Name = "IPDA_Zone_75Label_" + symbol;
    if(!::ObjectCreate(0, label75Name, OBJ_TEXT, 0, labelTime, g_IPDARange.Range75)) {
        LogError(symbol, "Failed to create 75% label");
    } else {
        ::ObjectSetString(0, label75Name, OBJPROP_TEXT, "75% Level");
        ::ObjectSetString(0, label75Name, OBJPROP_FONT, "Arial");
        ::ObjectSetInteger(0, label75Name, OBJPROP_FONTSIZE, 8);
        ::ObjectSetInteger(0, label75Name, OBJPROP_COLOR, clrDarkOrange);
    }
    
    // Mid label
    string midLabelName = "IPDA_Zone_MidLabel_" + symbol;
    if(!::ObjectCreate(0, midLabelName, OBJ_TEXT, 0, labelTime, g_IPDARange.Mid)) {
        LogError(symbol, "Failed to create mid label");
    } else {
        ::ObjectSetString(0, midLabelName, OBJPROP_TEXT, "Midpoint");
        ::ObjectSetString(0, midLabelName, OBJPROP_FONT, "Arial");
        ::ObjectSetInteger(0, midLabelName, OBJPROP_FONTSIZE, 8);
        ::ObjectSetInteger(0, midLabelName, OBJPROP_COLOR, clrWhite);
    }
    
    // 25% label
    string label25Name = "IPDA_Zone_25Label_" + symbol;
    if(!::ObjectCreate(0, label25Name, OBJ_TEXT, 0, labelTime, g_IPDARange.Range25)) {
        LogError(symbol, "Failed to create 25% label");
    } else {
        ::ObjectSetString(0, label25Name, OBJPROP_TEXT, "25% Level");
        ::ObjectSetString(0, label25Name, OBJPROP_FONT, "Arial");
        ::ObjectSetInteger(0, label25Name, OBJPROP_FONTSIZE, 8);
        ::ObjectSetInteger(0, label25Name, OBJPROP_COLOR, clrDarkOrange);
    }
    
    // Low label
    string lowLabelName = "IPDA_Zone_LowLabel_" + symbol;
    if(!::ObjectCreate(0, lowLabelName, OBJ_TEXT, 0, labelTime, g_IPDARange.Low)) {
        LogError(symbol, "Failed to create low label");
    } else {
        ::ObjectSetString(0, lowLabelName, OBJPROP_TEXT, "Range Low");
        ::ObjectSetString(0, lowLabelName, OBJPROP_FONT, "Arial");
        ::ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 8);
        ::ObjectSetInteger(0, lowLabelName, OBJPROP_COLOR, clrGreen);
    }
    
    // Force chart redraw
    ::ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Check if price is currently sweeping a level                     |
//+------------------------------------------------------------------+
bool IsCurrentlySweepingLevel(string symbol, double level, ENUM_SWEEP_TYPE sweepType) {
    // Get current candlestick data
    double high = ::iHigh(symbol, PERIOD_CURRENT, 0);
    double low = ::iLow(symbol, PERIOD_CURRENT, 0);
    double close = ::iClose(symbol, PERIOD_CURRENT, 0);
    double open = ::iOpen(symbol, PERIOD_CURRENT, 0);
    
    // Check for high sweep
    if ((sweepType == SWEEP_HIGH || sweepType == SWEEP_BOTH) && 
        high > level && close < level) {
        return true;
    }
    
    // Check for low sweep
    if ((sweepType == SWEEP_LOW || sweepType == SWEEP_BOTH) && 
        low < level && close > level) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if price was above a level in recent candles               |
//+------------------------------------------------------------------+
bool WasPriceAbove(string symbol, double level, int candles) {
    for (int i = 1; i <= candles; i++) {
        if (::iClose(symbol, PERIOD_CURRENT, i) > level) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if price was below a level in recent candles               |
//+------------------------------------------------------------------+
bool WasPriceBelow(string symbol, double level, int candles) {
    for (int i = 1; i <= candles; i++) {
        if (::iClose(symbol, PERIOD_CURRENT, i) < level) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Detect if the midpoint has been respected recently               |
//+------------------------------------------------------------------+
bool DetectMidpointConfirmation(string symbol, ENUM_TIMEFRAMES tf) {
    // Check for recent respect of midpoint
    double midpoint = g_HTFRangeMid;
    int lookback = 5;
    
    // Count times price approached midpoint (within 10 pips) but didn't close beyond it
    int respectedMid = 0;
    
    for (int i = 1; i <= lookback; i++) {
        double high = ::iHigh(symbol, tf, i);
        double low = ::iLow(symbol, tf, i);
        double close = ::iClose(symbol, tf, i);
        double distanceToMid = ::MathAbs(close - midpoint);
        
        // Price approached midpoint
        if (high >= midpoint && low <= midpoint) {
            // But respected it (closed on same side it opened from)
            if ((close > midpoint && ::iOpen(symbol, tf, i) > midpoint) ||
                (close < midpoint && ::iOpen(symbol, tf, i) < midpoint)) {
                respectedMid++;
            }
        }
    }
    
    return (respectedMid >= 2); // At least 2 candles respected the midpoint
}

//+------------------------------------------------------------------+
//| Check if any range levels have been swept by price                |
//+------------------------------------------------------------------+
void CheckRangeSweeps(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Get the last 3 candles for sweep detection
    double highPrices[], lowPrices[], closePrices[];
    
    if(::CopyHigh(symbol, timeframe, 0, 3, highPrices) != 3 ||
       ::CopyLow(symbol, timeframe, 0, 3, lowPrices) != 3 ||
       ::CopyClose(symbol, timeframe, 0, 3, closePrices) != 3) {
        LogError("RANGE", "Failed to copy price data for sweep detection");
        return;
    }
    
    // Check for high sweep
    if(highPrices[0] > g_HTFRangeHigh && closePrices[0] < g_HTFRangeHigh) {
        g_IPDARange.HighSwept = true;
        LogInfo("RANGE", "High range level swept");
        VisualizeRangeSweep(symbol, g_HTFRangeHigh, "High");
    }
    
    // Check for low sweep
    if(lowPrices[0] < g_HTFRangeLow && closePrices[0] > g_HTFRangeLow) {
        g_IPDARange.LowSwept = true;
        LogInfo("RANGE", "Low range level swept");
        VisualizeRangeSweep(symbol, g_HTFRangeLow, "Low");
    }
    
    // Check for mid sweep
    if((lowPrices[0] < g_HTFRangeMid && highPrices[0] > g_HTFRangeMid) && 
       (::MathAbs(closePrices[0] - g_HTFRangeMid) > 10 * ::_Point)) {
        g_IPDARange.MidSwept = true;
        LogInfo("RANGE", "Mid range level swept");
        VisualizeRangeSweep(symbol, g_HTFRangeMid, "Mid");
    }
}

//+------------------------------------------------------------------+
//| Remove existing IPDA zone objects                                 |
//+------------------------------------------------------------------+
void RemoveIPDAZoneObjects(string symbol) {
    string objPrefix = "IPDA_Range";
    
    for(int i = ::ObjectsTotal(0, 0, OBJ_HLINE) - 1; i >= 0; i--) {
        string objName = ::ObjectName(0, i, 0, OBJ_HLINE);
        
        if(::StringFind(objName, objPrefix) >= 0 && ::StringFind(objName, symbol) >= 0) {
            ::ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Visualize a range level sweep                                     |
//+------------------------------------------------------------------+
void VisualizeRangeSweep(string symbol, double level, string levelName) {
    string sweepObjName = "IPDA_Sweep_" + levelName + "_" + symbol;
    
    // Find the time of the sweep (last 5 candles)
    datetime times[];
    double highs[], lows[];
    
    if(::CopyTime(symbol, PERIOD_CURRENT, 0, 5, times) != 5 ||
       ::CopyHigh(symbol, PERIOD_CURRENT, 0, 5, highs) != 5 ||
       ::CopyLow(symbol, PERIOD_CURRENT, 0, 5, lows) != 5) {
        LogError("RANGE", "Failed to copy data for sweep visualization");
        return;
    }
    
    // Find the candle that likely caused the sweep
    int sweepCandle = -1;
    for(int i = 0; i < 5; i++) {
        if(highs[i] >= level && lows[i] <= level) {
            sweepCandle = i;
            break;
        }
    }
    
    if(sweepCandle == -1) {
        // Use current time if we can't find the exact candle
        sweepCandle = 0;
    }
    
    // Create sweep marker
    ::ObjectCreate(0, sweepObjName, OBJ_ARROW, 0, times[sweepCandle], level);
    ::ObjectSetInteger(0, sweepObjName, OBJPROP_ARROWCODE, 234); // Exclamation mark
    ::ObjectSetInteger(0, sweepObjName, OBJPROP_COLOR, clrRed);
    ::ObjectSetInteger(0, sweepObjName, OBJPROP_WIDTH, 2);
    ::ObjectSetString(0, sweepObjName, OBJPROP_TEXT, "Sweep: " + levelName);
}

//+------------------------------------------------------------------+
//| Function to check if a price level is near a range zone           |
//+------------------------------------------------------------------+
bool IsPriceNearRangeZone(string symbol, double price, double &nearestZone) {
    double currentPrice = price;
    if(price == 0.0) {
        currentPrice = ::SymbolInfoDouble(symbol, SYMBOL_BID);
    }
    
    // Define proximity threshold (0.2% of price)
    double threshold = currentPrice * 0.002;
    
    // Check each range zone
    double zones[] = {g_HTFRangeHigh, g_HTFRange75, g_HTFRangeMid, g_HTFRange25, g_HTFRangeLow};
    double minDistance = threshold;
    nearestZone = 0.0;
    
    for(int i = 0; i < ::ArraySize(zones); i++) {
        double distance = ::MathAbs(currentPrice - zones[i]);
        
        if(distance < minDistance) {
            minDistance = distance;
            nearestZone = zones[i];
        }
    }
    
    return (nearestZone > 0.0);
}

// Note: We're removing the duplicate CleanIPDAZones function
// and will use the one from IPDA_
// Note: We're removing the duplicate CleanIPDAZones function
// and will use the one from IPDA_Utility.mqh instead

//+------------------------------------------------------------------+
//| Detect if a sweep occurred at a specific level                    |
//+------------------------------------------------------------------+
bool IsSweepDetected(string symbol, ENUM_TIMEFRAMES timeframe, double level, ENUM_SWEEP_TYPE type) {
    // Get the last 3 candles for sweep detection
    double high[], low[], close[];
    
    if(::CopyHigh(symbol, timeframe, 0, 3, high) != 3 ||
       ::CopyLow(symbol, timeframe, 0, 3, low) != 3 ||
       ::CopyClose(symbol, timeframe, 0, 3, close) != 3) {
        LogError("SWEEP", "Failed to copy price data for sweep detection");
        return false;
    }
    
    // Check for high sweep
    if ((type == SWEEP_HIGH || type == SWEEP_BOTH) && 
        high[0] > level && close[0] < level) {
        return true;
    }
    
    // Check for low sweep
    if ((type == SWEEP_LOW || type == SWEEP_BOTH) && 
        low[0] < level && close[0] > level) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Visualize a sweep on the chart                                    |
//+------------------------------------------------------------------+
void VisualizeSweep(string symbol, double level, ENUM_SWEEP_TYPE type) {
    string sweepType = (type == SWEEP_HIGH) ? "High" : 
                      (type == SWEEP_LOW) ? "Low" : "Both";
    string objName = "IPDA_Sweep_" + sweepType + "_" + ::DoubleToString(level, 5) + "_" + symbol;
    
    // Get current time for the marker
    datetime currentTime = ::TimeCurrent();
    
    // Create a marker at the sweep level
    if (!::ObjectCreate(0, objName, OBJ_ARROW, 0, currentTime, level)) {
        LogError("SWEEP", "Failed to create sweep marker");
        return;
    }
    
    // Set marker properties
    int arrowCode = (type == SWEEP_HIGH) ? 233 : // Arrow pointing down
                   (type == SWEEP_LOW) ? 234 :   // Arrow pointing up
                   217;                          // Star for both
    
    color arrowColor = (type == SWEEP_HIGH) ? clrRed : 
                      (type == SWEEP_LOW) ? clrGreen : 
                      clrYellow;
    
    ::ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
    ::ObjectSetInteger(0, objName, OBJPROP_COLOR, arrowColor);
    ::ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ::ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
    
    // Add a text label with the sweep information
    string labelName = objName + "_Label";
    if (::ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime + ::PeriodSeconds(PERIOD_CURRENT) * 3, level)) {
        ::ObjectSetString(0, labelName, OBJPROP_TEXT, "Sweep " + sweepType + " @ " + ::DoubleToString(level, 5));
        ::ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
        ::ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
        ::ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
    }
    
    // Force chart redraw
    ::ChartRedraw(0);
}

#endif  // __IPDA_RANGE__
