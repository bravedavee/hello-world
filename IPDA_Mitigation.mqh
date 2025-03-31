//+------------------------------------------------------------------+
//| IPDA_Mitigation.mqh - Zone mitigation detection module           |
//+------------------------------------------------------------------+
#ifndef __IPDA_MITIGATION__
#define __IPDA_MITIGATION__

// Include necessary files in correct order
#include "IPDA_ExternalFunctions.mqh"  // Centralized DLL imports first
#include "IPDA_Globals.mqh"            // Global definitions
#include "IPDA_Logger.mqh"             // Logging functions
#include <Trade/Trade.mqh>             // Standard MQL5 libraries last

// Forward declarations
extern SweepSignal g_RecentSweep;
extern IPDARange g_IPDARange;
extern MTFRegimeInfo g_MTFRegimes;

//+------------------------------------------------------------------+
//| Function Prototypes                                              |
//+------------------------------------------------------------------+
bool CheckZoneMitigation(string symbol, ElementZone &zone, bool isHVN = false);
void MarkZoneMitigated(string symbol, ElementZone &zone, double mitigationLevel);
bool HasZoneBeenMitigated(ElementZone &zone);
void VisualizeZoneMitigation(string symbol, ElementZone &zone);

//+------------------------------------------------------------------+
//| Check if price has mitigated a zone                              |
//+------------------------------------------------------------------+
bool CheckZoneMitigation(string symbol, ElementZone &zone, bool isHVN = false) {
    // Skip invalid zones
    if (zone.IsInvalidated || zone.PriceTop <= 0.0 || zone.PriceBottom <= 0.0) {
        return false;
    }
    
    // ✅ Validated against MQL5 docs: use global namespace for built-in functions
    double currentPrice = ::SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // For bullish zones (bottom < top), mitigated by price falling below bottom
    if (zone.PriceBottom < zone.PriceTop) {
        // Special handling for HVN (High Volume Node) zones
        if (isHVN) {
            // HVN is mitigated when price touches either boundary
            if (currentPrice <= zone.PriceBottom || currentPrice >= zone.PriceTop) {
                MarkZoneMitigated(symbol, zone, currentPrice);
                return true;
            }
        } 
        // Standard zone mitigation - price must breach the bottom
        else if (currentPrice < zone.PriceBottom) {
            MarkZoneMitigated(symbol, zone, currentPrice);
            return true;
        }
    }
    // For bearish zones (top < bottom), mitigated by price rising above top
    else if (zone.PriceTop < zone.PriceBottom) {
        if (isHVN) {
            if (currentPrice <= zone.PriceTop || currentPrice >= zone.PriceBottom) {
                MarkZoneMitigated(symbol, zone, currentPrice);
                return true;
            }
        }
        else if (currentPrice > zone.PriceBottom) {
            MarkZoneMitigated(symbol, zone, currentPrice);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Mark a zone as mitigated                                         |
//+------------------------------------------------------------------+
void MarkZoneMitigated(string symbol, ElementZone &zone, double mitigationLevel) {
    zone.IsInvalidated = true;
    zone.MitigationLevel = mitigationLevel;
    
    LogInfo(symbol, "Zone " + zone.Name + " mitigated at " + 
            ::DoubleToString(mitigationLevel, ::SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
    
    VisualizeZoneMitigation(symbol, zone);
}

//+------------------------------------------------------------------+
//| Check if a zone has already been mitigated                       |
//+------------------------------------------------------------------+
bool HasZoneBeenMitigated(ElementZone &zone) {
    return zone.IsInvalidated && zone.MitigationLevel > 0.0;
}

//+------------------------------------------------------------------+
//| Visualize a mitigated zone on the chart                          |
//+------------------------------------------------------------------+
void VisualizeZoneMitigation(string symbol, ElementZone &zone) {
    string objectName = zone.Name + "_" + symbol;
    
    // Update existing zone object if it exists
    if (::ObjectFind(0, objectName) >= 0) {
        ::ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrDarkGray);
        ::ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_DOT);
        ::ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 1);
        
        // Add mitigation marker
        string mitigationName = objectName + "_Mitigation";
        if (!::ObjectFind(0, mitigationName)) {
            ::ObjectCreate(0, mitigationName, OBJ_ARROW, 0, 
                          (datetime)::TimeCurrent(), zone.MitigationLevel);
            ::ObjectSetInteger(0, mitigationName, OBJPROP_ARROWCODE, 251); // Check mark
            ::ObjectSetInteger(0, mitigationName, OBJPROP_COLOR, clrLimeGreen);
            ::ObjectSetInteger(0, mitigationName, OBJPROP_WIDTH, 2);
            
            // Add mitigation label
            string labelName = mitigationName + "_Label";
            ::ObjectCreate(0, labelName, OBJ_TEXT, 0, 
                          (datetime)(::TimeCurrent() + 10000), zone.MitigationLevel);
            ::ObjectSetString(0, labelName, OBJPROP_TEXT, "Mitigated");
            ::ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLimeGreen);
        }
    }
}

#endif // __IPDA_MITIGATION__
