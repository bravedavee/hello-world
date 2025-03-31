//+------------------------------------------------------------------+
//| IPDA_Utility.mqh - Common utility functions for the IPDA system   |
//+------------------------------------------------------------------+
#ifndef __IPDA_UTILITY__
#define __IPDA_UTILITY__

// Standard include order
#include "IPDA_DLLImports.mqh"
#include "IPDA_ExternalFunctions.mqh"
#include "IPDA_Globals.mqh"  // This already includes IPDA_TimeFrames.mqh
#include "IPDA_Logger.mqh"

//+------------------------------------------------------------------+
//|                    ZONE MANAGEMENT FUNCTIONS                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Assign values to an ElementZone structure                         |
//+------------------------------------------------------------------+
void AssignZone(ElementZone &zone, string name, double top, double bottom, datetime startTime) {
    // Set primary zone properties
    zone.Name = name;
    zone.PriceTop = top;
    zone.PriceBottom = bottom;
    zone.TimeStart = startTime;
    zone.TimeEnd = TimeCurrent() + PeriodSeconds(PERIOD_D1) * 5; // 5 days forward
    zone.IsInvalidated = false;
    zone.MitigationLevel = 0.0;
    
    // Set alternative field names for compatibility
    zone.upper = top;
    zone.lower = bottom;
    zone.time = startTime;
    zone.label = name;
    zone.isActive = true;
    
    // Ensure top is higher than bottom
    if (zone.PriceTop < zone.PriceBottom) {
        double temp = zone.PriceTop;
        zone.PriceTop = zone.PriceBottom;
        zone.PriceBottom = temp;
        
        // Also swap alternative field names
        zone.upper = zone.PriceTop;
        zone.lower = zone.PriceBottom;
    }
    
    LogInfo("ZONE", "Created " + name + " zone: " + DoubleToString(zone.PriceTop, _Digits) + 
            " to " + DoubleToString(zone.PriceBottom, _Digits));
}

//+------------------------------------------------------------------+
//| Invalidate a zone (mark as no longer active)                      |
//+------------------------------------------------------------------+
void InvalidateZone(ElementZone &zone) {
    zone.IsInvalidated = true;
    zone.isActive = false;  // Set alternative field for compatibility
    
    LogInfo("ZONE", "Invalidated " + zone.Name + " zone");
}

//+------------------------------------------------------------------+
//| Check if price is inside a zone                                   |
//+------------------------------------------------------------------+
bool IsPriceInZone(ElementZone &zone, double price) {
    if (zone.IsInvalidated) return false;
    
    return (price <= zone.PriceTop && price >= zone.PriceBottom);
}

//+------------------------------------------------------------------+
//| Check if a zone has been mitigated (price revisited)              |
//+------------------------------------------------------------------+
bool IsZoneMitigated(ElementZone &zone, double price, double thresholdPercent = 50.0) {
    if (zone.IsInvalidated) return true;
    
    double zoneHeight = zone.PriceTop - zone.PriceBottom;
    double thresholdPips = zoneHeight * (thresholdPercent / 100.0);
    
    // For bullish zones, we check if price retraced back down into the zone
    if (zone.Name.Find("Bull") >= 0 || zone.Name.Find("BUY") >= 0) {
        return (price <= zone.PriceTop && price >= (zone.PriceTop - thresholdPips));
    }
    // For bearish zones, we check if price retraced back up into the zone
    else if (zone.Name.Find("Bear") >= 0 || zone.Name.Find("SELL") >= 0) {
        return (price >= zone.PriceBottom && price <= (zone.PriceBottom + thresholdPips));
    }
    
    // For unnamed zones, check if price is anywhere in the zone
    return IsPriceInZone(zone, price);
}

//+------------------------------------------------------------------+
//| Mark a zone as mitigated with the current price                   |
//+------------------------------------------------------------------+
void MitigateZone(ElementZone &zone, double price) {
    zone.MitigationLevel = price;
    LogInfo("ZONE", "Mitigated " + zone.Name + " zone at price " + DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| Clean up chart objects related to IPDA zones                      |
//+------------------------------------------------------------------+
void CleanIPDAZones(string symbol) {
    int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
        if (StringFind(name, "IPDA_") >= 0 && StringFind(name, symbol) >= 0) {
            ObjectDelete(0, name);
            ObjectDelete(0, name + "_Label");
        }
    }
}

//+------------------------------------------------------------------+
//| Clean up chart objects related to breakout markers                |
//+------------------------------------------------------------------+
void CleanBreakoutMarkers(string symbol) {
    int total = ObjectsTotal(0, 0, OBJ_ARROW);
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, OBJ_ARROW);
        if (StringFind(name, "Breakout_") >= 0 && StringFind(name, symbol) >= 0) {
            ObjectDelete(0, name);
        }
    }
}

//+------------------------------------------------------------------+
//| Clean up chart objects related to confluence indicators           |
//+------------------------------------------------------------------+
void CleanConfluenceMarkers(string symbol) {
    int total = ObjectsTotal(0, 0, OBJ_TEXT);
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, OBJ_TEXT);
        if (StringFind(name, "Confluence_") >= 0 && StringFind(name, symbol) >= 0) {
            ObjectDelete(0, name);
        }
    }
}

//+------------------------------------------------------------------+
//|                   TIME FRAME UTILITY FUNCTIONS                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if we should process the current tick based on timeframe    |
//+------------------------------------------------------------------+
bool TimeFrameCheck(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(symbol, timeframe, 0);
    
    // Only process if a new bar has formed on the specified timeframe
    if (currentBarTime > lastBarTime) {
        lastBarTime = currentBarTime;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//|                    TRADE UTILITY FUNCTIONS                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate appropriate lot size based on risk percentage           |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double riskPercent, double stopLossPoints) {
    if (stopLossPoints <= 0) return 0.01; // Minimum lot size as failsafe
    
    // Get account balance and calculate risk amount
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (riskPercent / 100.0);
    
    // Calculate value per pip
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double pointValue = tickValue * (_Point / tickSize);
    
    // Calculate lot size based on risk
    double lotSize = riskAmount / (stopLossPoints * pointValue);
    
    // Adjust to symbol's lot step
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    lotSize = NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);
    
    // Apply min/max lot size constraints
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Convert setup quality enum to string for logging                  |
//+------------------------------------------------------------------+
string SetupQualityToString(ENUM_TRADE_SETUP_QUALITY quality) {
    switch(quality) {
        case TRADE_SETUP_STRONG: return "Strong";
        case TRADE_SETUP_MEDIUM: return "Medium";
        case TRADE_SETUP_WEAK: return "Weak";
        default: return "Unknown";
    }
}

#endif // __IPDA_UTILITY__
