//+------------------------------------------------------------------+
//| IPDA_Confluence.mqh - Confluence detection for entries           |
//+------------------------------------------------------------------+
#ifndef __IPDA_CONFLUENCE__
#define __IPDA_CONFLUENCE__

// Standard include order
#include "IPDA_ExternalFunctions.mqh"  // External DLL functions first
#include "IPDA_Globals.mqh"            // Global definitions
#include "IPDA_Logger.mqh"             // Then logger
#include <Trade/Trade.mqh>             // Then standard libraries

// Forward declare global variables from Main_EA.mq5
extern double g_HTFRangeHigh;
extern double g_HTFRange75; 
extern double g_HTFRangeMid;
extern double g_HTFRange25;
extern double g_HTFRangeLow;

// ✅ Using the CConfluenceContext class already declared in IPDA_Globals.mqh [Rule 4]]
// Implementation of member functions for the already declared class
void LogConfluence(CConfluenceContext &ctx) {
    string directionText = "Neutral";
    if (ctx.direction > 0) directionText = "Bullish";
    if (ctx.direction < 0) directionText = "Bearish";
    
    string elementText = "";
    if (ctx.hasOrderBlock) elementText += "OB ";
    if (ctx.hasSNRSweep) elementText += "SNR ";
    if (ctx.hasRJB) elementText += "RJB ";
    
    LogInfo("CONFLUENCE", "Direction: " + directionText + " | Elements: " + elementText + 
            " | Total: " + ::IntegerToString(ctx.totalElements));
}

// ✅ Correct function declarations with proper reference syntax
bool DetectHTFOrderBlock(string symbol, ENUM_TIMEFRAMES timeframe, bool isBullish, ElementZone &obZone);
bool DetectHTFRejectionBlock(string symbol, ENUM_TIMEFRAMES timeframe, ElementZone &rjbZone);
bool DetectMalaysianSNRSweep(string symbol, ENUM_TIMEFRAMES timeframe, ElementZone &snrSweep);
void VisualizeElement(string symbol, ElementZone &zone, color zoneColor);
void ScanHTFConfluence(string symbol, ENUM_TIMEFRAMES timeframe);
int DetermineConfluenceDirection(ElementZone &elements[], bool &strongConfluence);

//------------------------------------------------------------------------------
// ✅ Fix balanced brackets for all function implementations [Rule 4]
//------------------------------------------------------------------------------
bool DetectHTFOrderBlock(string symbol, ENUM_TIMEFRAMES timeframe, bool isBullish, ElementZone &obZone) {
    double obOpen = ::iOpen(symbol, timeframe, 1);
    double obClose = ::iClose(symbol, timeframe, 1);

    if ((isBullish && obClose > obOpen) || (!isBullish && obClose < obOpen)) {
        // ✅ Ensure proper function call and closing brackets [Rule 4]
        AssignZone(obZone, "HTF_OB", ::iHigh(symbol, timeframe, 1), 
                  ::iLow(symbol, timeframe, 1), ::iTime(symbol, timeframe, 1));
        return true;
    }
    return false;
} // ✅ Added missing closing bracket [Rule 4]

bool DetectHTFRejectionBlock(string symbol, ENUM_TIMEFRAMES timeframe, ElementZone &rjbZone) {
    double obClose = ::iClose(symbol, timeframe, 1);
    double obOpen = ::iOpen(symbol, timeframe, 1);

    if (obClose > obOpen)  // Bullish RJB
    {
        double lowPrice = ::iLow(symbol, timeframe, 1);
        AssignZone(rjbZone, "HTF_RJB", obClose, obClose + (obClose - lowPrice), ::iTime(symbol, timeframe, 1));
        return true;
    }
    if (obClose < obOpen)  // Bearish RJB
    {
        double highPrice = ::iHigh(symbol, timeframe, 1);
        AssignZone(rjbZone, "HTF_RJB", obClose, obClose - (highPrice - obClose), ::iTime(symbol, timeframe, 1));
        return true;
    }
    return false;
} // ✅ Ensure closing bracket [Rule 4]

bool DetectMalaysianSNRSweep(string symbol, ENUM_TIMEFRAMES timeframe, ElementZone &snrSweep) {
    double lastHigh = ::iHigh(symbol, timeframe, 1);
    double lastLow = ::iLow(symbol, timeframe, 1);
    double lastClose = ::iClose(symbol, timeframe, 1);

    if (lastHigh > g_HTFRangeHigh && lastClose < g_HTFRangeHigh) {
        AssignZone(snrSweep, "SNR_Sweep_High", lastHigh, g_HTFRangeHigh, ::iTime(symbol, timeframe, 1));
        return true;
    }

    if (lastLow < g_HTFRangeLow && lastClose > g_HTFRangeLow) {
        AssignZone(snrSweep, "SNR_Sweep_Low", g_HTFRangeLow, lastLow, ::iTime(symbol, timeframe, 1));
        return true;
    }

    return false;
} // ✅ Ensure closing bracket [Rule 4]

void VisualizeElement(string symbol, ElementZone &zone, color zoneColor) {
    string objectName = zone.Name + "_" + symbol;
    string labelName = objectName + "_Label";
    // ✅ Use global namespace operator consistently [Rule 1]
    if (!::ObjectFind(0, objectName)) {
        ::ObjectCreate(0, objectName, OBJ_RECTANGLE, 0, zone.TimeStart, zone.PriceTop, zone.TimeStart, zone.PriceBottom);
        ::ObjectSetInteger(0, objectName, OBJPROP_COLOR, zoneColor);
        ::ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_SOLID);
        ::ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
        ::ObjectSetInteger(0, objectName, OBJPROP_BACK, true);
        ::ObjectCreate(0, labelName, OBJ_TEXT, 0, zone.TimeStart, zone.PriceTop);
        ::ObjectSetString(0, labelName, OBJPROP_TEXT, zone.Name);
        ::ObjectSetInteger(0, labelName, OBJPROP_COLOR, zoneColor);
        ::ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
    } else {
        ::ObjectMove(0, objectName, 0, zone.TimeStart, zone.PriceTop);
        ::ObjectMove(0, objectName, 1, zone.TimeStart, zone.PriceBottom);
        ::ObjectSetInteger(0, objectName, OBJPROP_COLOR, zoneColor);
        ::ObjectSetInteger(0, labelName, OBJPROP_COLOR, zoneColor);
        if (zone.IsInvalidated) {
            ::ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrGray);
            ::ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGray);
        }
    }
}

void ScanHTFConfluence(string symbol, ENUM_TIMEFRAMES timeframe) {
    ElementZone elements[3];
    CConfluenceContext ctx;
       
    // Store timeframe for reference
    ctx.timeframe = timeframe;
    ctx.category = "HTF";

    // Detect elements
    ctx.hasOrderBlock = DetectHTFOrderBlock(symbol, timeframe, true, elements[0]);
    if (ctx.hasOrderBlock) VisualizeElement(symbol, elements[0], clrDodgerBlue);

    ctx.hasSNRSweep = DetectMalaysianSNRSweep(symbol, timeframe, elements[1]);
    if (ctx.hasSNRSweep) VisualizeElement(symbol, elements[1], clrRed);

    ctx.hasRJB = DetectHTFRejectionBlock(symbol, timeframe, elements[2]);
    if (ctx.hasRJB) VisualizeElement(symbol, elements[2], clrGreen);

    // Determine direction and log
    bool strongConfluence = false;
    ctx.direction = DetermineConfluenceDirection(elements, strongConfluence);
    ctx.totalElements = (ctx.hasOrderBlock ? 1 : 0) +
                        (ctx.hasSNRSweep ? 1 : 0) +
                        (ctx.hasRJB ? 1 : 0);

    LogConfluence(ctx);
} // ✅ Ensure closing bracket [Rule 4]

// Fix line 183-186 where warnings occur
int DetermineConfluenceDirection(ElementZone &elements[], bool &strongConfluence) {
    strongConfluence = false;
    int bullCount = 0;
    int bearCount = 0;

    // Check Order Block Direction
    // ✅ Corrected according to [Namespace Resolution Enforcement] [Rule 1]
    if (::StringFind(elements[0].Name, "HTF_OB") != -1) {
        // ✅ Use global namespace operator consistently [Rule 1]
        double obOpen = ::iOpen(::Symbol(), PERIOD_CURRENT, 1);
        double obClose = ::iClose(::Symbol(), PERIOD_CURRENT, 1);
        if (obClose > obOpen) bullCount++;
        if (obClose < obOpen) bearCount++;
    }

    // ✅ Corrected according to [Namespace Resolution Enforcement] [Rule 1]
    // Check SNR Sweep Direction
    if (::StringFind(elements[1].Name, "SNR_Sweep_High") != -1) {
        bearCount++;  // High sweeps typically signal bearish continuation
    } 
    else if (::StringFind(elements[1].Name, "SNR_Sweep_Low") != -1) {
        bullCount++;  // Low sweeps typically signal bullish continuation
    }

    // ✅ Corrected according to [Namespace Resolution Enforcement] [Rule 1]
    // Check Rejection Block Direction
    if (::StringFind(elements[2].Name, "HTF_RJB") != -1) {
        // For RJB, we need to check if it's rejecting from top or bottom
        if (elements[2].PriceTop > g_HTFRangeMid) {
            bearCount++;  // Rejection from above midpoint is bearish
        } else {
            bullCount++;  // Rejection from below midpoint is bullish
        }
    }

    // Determine if confluence is strong (2+ elements agree on direction)
    strongConfluence = (bullCount >= 2 || bearCount >= 2);
    
    // Return direction
    if (bullCount > bearCount) return 1;  // Bullish
    if (bearCount > bullCount) return -1; // Bearish
    return 0; // Neutral
}

#endif  // __IPDA_CONFLUENCE__
