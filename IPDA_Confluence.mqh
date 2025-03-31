//+------------------------------------------------------------------+
//| IPDA_Confluence.mqh - Confluence detection for entries           |
//+------------------------------------------------------------------+
#ifndef __IPDA_CONFLUENCE__
#define __IPDA_CONFLUENCE__

// Standard include order
#include "IPDA_ExternalFunctions.mqh"  // External DLL functions first
#include "IPDA_Globals.mqh"            // Global definitions
#include "IPDA_Logger.mqh"             // Then logger
#include "IPDA_Utility.mqh"            // Add utility functions include for AssignZone
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
} // Fixed missing closing bracket

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
    
    // Check Higher Timeframe Direction first for bias
    int htfBias = GetHigherTimeframeBias(Symbol());
    
    // Give initial bias from HTF direction
    if (htfBias > 0) bullCount += 1;
    if (htfBias < 0) bearCount += 1;

    // Check Order Block Direction
    if (::StringFind(elements[0].Name, "HTF_OB") != -1 || ::StringFind(elements[0].Name, "LTF_Bullish_OB") != -1) {
        double obOpen = ::iOpen(::Symbol(), PERIOD_CURRENT, 1);
        double obClose = ::iClose(::Symbol(), PERIOD_CURRENT, 1);
        if (obClose > obOpen) bullCount += 2; // Increased weight for orderblocks
        if (obClose < obOpen) bearCount += 2;
    }

    // Check SNR Sweep Direction
    if (::StringFind(elements[1].Name, "SNR_Sweep_High") != -1) {
        bearCount += 1;  // High sweeps typically signal bearish continuation
    } 
    else if (::StringFind(elements[1].Name, "SNR_Sweep_Low") != -1) {
        bullCount += 1;  // Low sweeps typically signal bullish continuation
    }
    else if (::StringFind(elements[1].Name, "SNR_Sweep_Mid") != -1) {
        // Mid sweeps need further context from the sweep object
        if (g_SweepDirectionBull)
            bullCount += 1;
        else
            bearCount += 1;
    }

    // Check Rejection Block Direction
    if (::StringFind(elements[2].Name, "RJB") != -1) {
        // RJB direction depends on its position relative to price
        double currentPrice = ::iClose(::Symbol(), PERIOD_CURRENT, 0);
        if (currentPrice > elements[2].PriceTop) 
            bullCount += 1;
        else if (currentPrice < elements[2].PriceBottom)
            bearCount += 1;
    }
    
    // Add a momentum component
    double h1Momentum = CalculateMomentum(Symbol(), PERIOD_H1);
    if (h1Momentum > 0.3) bullCount += 1;  // Strong upward momentum
    if (h1Momentum < -0.3) bearCount += 1; // Strong downward momentum
    
    // Check for strong confluence (3+ factors in same direction)
    strongConfluence = (bullCount >= 3 || bearCount >= 3);
    
    // Return direction: 1 for bullish, -1 for bearish, 0 for neutral/conflicted
    if (bullCount > bearCount) return 1;
    if (bearCount > bullCount) return -1;
    return 0; // Neutral or conflicted direction
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe bias from Daily/H4 direction                |
//+------------------------------------------------------------------+
int GetHigherTimeframeBias(string symbol) {
    // Look at both Daily and H4 timeframes for consistent direction
    
    // Check Daily timeframe
    double dailyClose = iClose(symbol, PERIOD_D1, 1);
    double dailyOpen = iOpen(symbol, PERIOD_D1, 1);
    
    // Get Daily SMA using indicator handle
    int dailySma50Handle = iMA(symbol, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);
    double dailySma50Buffer[];
    ArraySetAsSeries(dailySma50Buffer, true);
    CopyBuffer(dailySma50Handle, 0, 1, 1, dailySma50Buffer);
    double dailySma50 = dailySma50Buffer[0];
    
    int dailyBias = 0;
    if (dailyClose > dailyOpen && dailyClose > dailySma50) dailyBias = 1;
    if (dailyClose < dailyOpen && dailyClose < dailySma50) dailyBias = -1;
    
    // Check H4 timeframe
    double h4Close = iClose(symbol, PERIOD_H4, 1);
    double h4Open = iOpen(symbol, PERIOD_H4, 1);
    
    // Get H4 SMA using indicator handle
    int h4Sma50Handle = iMA(symbol, PERIOD_H4, 50, 0, MODE_SMA, PRICE_CLOSE);
    double h4Sma50Buffer[];
    ArraySetAsSeries(h4Sma50Buffer, true);
    CopyBuffer(h4Sma50Handle, 0, 1, 1, h4Sma50Buffer);
    double h4Sma50 = h4Sma50Buffer[0];
    
    int h4Bias = 0;
    if (h4Close > h4Open && h4Close > h4Sma50) h4Bias = 1;
    if (h4Close < h4Open && h4Close < h4Sma50) h4Bias = -1;
    
    // If both agree, that's our bias
    if (dailyBias == h4Bias && dailyBias != 0) return dailyBias;
    
    // If they disagree, give more weight to Daily
    if (dailyBias != 0) return dailyBias;
    
    // Otherwise use H4 or return neutral
    return h4Bias;
}

#endif  // __IPDA_CONFLUENCE__
