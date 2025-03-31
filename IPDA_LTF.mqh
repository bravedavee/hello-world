//+------------------------------------------------------------------+
//| IPDA_LTF.mqh - Low Timeframe Detection Module                    |
//+------------------------------------------------------------------+
#ifndef __IPDA_LTF__
#define __IPDA_LTF__

// Include necessary headers
#include "IPDA_ExternalFunctions.mqh"  // For DLL functions
#include "IPDA_Globals.mqh"            // For global variables and types
#include "IPDA_Logger.mqh"             // For logging
// Remove the direct include of IPDA_TimeFrames.mqh as it's already included via IPDA_Globals.mqh

// External global variables needed by this module
extern double g_HTFRangeHigh;
extern double g_HTFRange75;
extern double g_HTFRangeMid; 
extern double g_HTFRange25;
extern double g_HTFRangeLow;

// Function prototypes for functions defined elsewhere
extern void AssignZone(ElementZone &zone, string name, double top, double bottom, datetime startTime);

//+------------------------------------------------------------------+
//| Detect LTF Stacked Fair Value Gap                                |
//+------------------------------------------------------------------+
bool DetectLTFStackedFVG(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum, ElementZone &fvgZone) {
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    int stackedCount = 0;  // Tracks stacked FVG instances

    // Use global namespace operator for built-in functions
    for (int i = 1; i <= 5; i++) {
        double prevHigh = ::iHigh(symbol, ltfTimeframe, i + 1);
        double currLow = ::iLow(symbol, ltfTimeframe, i);
        double prevLow = ::iLow(symbol, ltfTimeframe, i + 1);
        double currHigh = ::iHigh(symbol, ltfTimeframe, i);

        // ✅ Bullish Stacked FVG
        if (currLow > prevHigh) {
            stackedCount++;
            AssignZone(fvgZone, "LTF_FVG_Bullish", currLow, prevHigh, (datetime)::iTime(symbol, ltfTimeframe, i));
        }

        // ✅ Bearish Stacked FVG
        if (currHigh < prevLow) {
            stackedCount++;
            AssignZone(fvgZone, "LTF_FVG_Bearish", prevLow, currHigh, (datetime)::iTime(symbol, ltfTimeframe, i));
        }

        if (stackedCount >= 2) {
            LogInfo(symbol, "Multiple Stacked FVGs Detected on LTF.");
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Detect LTF Order Block within IPDA Zones                         |
//+------------------------------------------------------------------+
// ✅ Fixed proper reference parameter implementation
bool DetectLTFOrderBlock(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum, bool isBullish, ElementZone &obZone) {
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    for (int i = 1; i <= 10; i++) {
        double obOpen = ::iOpen(symbol, ltfTimeframe, i);
        double obClose = ::iClose(symbol, ltfTimeframe, i);
        double obHigh = ::iHigh(symbol, ltfTimeframe, i);
        double obLow = ::iLow(symbol, ltfTimeframe, i);

        // ✅ Bullish Order Block
        if (isBullish && obClose > obOpen && obLow >= g_HTFRange25 && obLow <= g_HTFRange75) {
            AssignZone(obZone, "LTF_Bullish_OB", obHigh, obLow, (datetime)::iTime(symbol, ltfTimeframe, i));
            return true;
        }

        // ✅ Bearish Order Block
        if (!isBullish && obClose < obOpen && obHigh <= g_HTFRange75 && obHigh >= g_HTFRange25) {
            AssignZone(obZone, "LTF_Bearish_OB", obHigh, obLow, (datetime)::iTime(symbol, ltfTimeframe, i));
            return true;
        }
    }
    return false;
}

// ✅ Fixed overload for ENUM_TIMEFRAMES to avoid function signature confusion
bool DetectLTFOrderBlock(string symbol, ENUM_TIMEFRAMES timeframe, bool isBullish, ElementZone &obZone) {
    // Convert standard timeframe to LTF enum using the helper function
    ENUM_LTF_TIMEFRAMES ltfEnum = StandardToLTFTimeframe(timeframe);
    return DetectLTFOrderBlock(symbol, ltfEnum, isBullish, obZone);
}

//+------------------------------------------------------------------+
//| Detect LTF Rejection Block                                       |
//+------------------------------------------------------------------+
bool DetectLTFRejectionBlock(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum, ElementZone &rjbZone) {
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    for (int i = 1; i <= 10; i++) {
        double obClose = ::iClose(symbol, ltfTimeframe, i);  // Add global namespace
        double obOpen = ::iOpen(symbol, ltfTimeframe, i);  // Add global namespace
        double obLow = ::iLow(symbol, ltfTimeframe, i);  // Add global namespace
        double obHigh = ::iHigh(symbol, ltfTimeframe, i);  // Add global namespace

        // ✅ Bullish Rejection Block
        if (obClose > obOpen && obLow >= g_HTFRange25 && obLow <= g_HTFRange75) {
            AssignZone(rjbZone, "LTF_Bullish_RJB", obClose, obClose + (obClose - obLow), (datetime)::iTime(symbol, ltfTimeframe, i));
            return true;
        }

        // ✅ Bearish Rejection Block
        if (obClose < obOpen && obHigh <= g_HTFRange75 && obHigh >= g_HTFRange25) {
            AssignZone(rjbZone, "LTF_Bearish_RJB", obClose, obClose - (obHigh - obClose), (datetime)::iTime(symbol, ltfTimeframe, i));
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Pivot Breakout Identification with Volume/Momentum Conditions    |
//+------------------------------------------------------------------+
bool DetectPivotBreakout(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum, ElementZone &pivotZone) {
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    for (int i = 1; i <= 5; i++) {
        double prevHigh = ::iHigh(symbol, ltfTimeframe, i + 1);
        double currHigh = ::iHigh(symbol, ltfTimeframe, i);
        double prevLow = ::iLow(symbol, ltfTimeframe, i + 1);
        double currLow = ::iLow(symbol, ltfTimeframe, i);
        long currVolume = ::iVolume(symbol, ltfTimeframe, i);

        // ✅ Bullish Breakout with Volume Surge
        if (currHigh > prevHigh && currLow >= g_HTFRangeMid && currVolume > ::iVolume(symbol, ltfTimeframe, i + 1)) {
            AssignZone(pivotZone, "LTF_Pivot_Bullish", currHigh, currLow, (datetime)::iTime(symbol, ltfTimeframe, i));
            return true;
        }

        // ✅ Bearish Breakout with Momentum Confirmation
        if (currLow < prevLow && currHigh <= g_HTFRangeMid && currVolume > ::iVolume(symbol, ltfTimeframe, i + 1)) {
            AssignZone(pivotZone, "LTF_Pivot_Bearish", currHigh, currLow, (datetime)::iTime(symbol, ltfTimeframe, i));
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| True Rejection Pattern Detection                                 |
//+------------------------------------------------------------------+
bool DetectTrueRejectionPattern(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum, ElementZone &rejZone) {
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    for (int i = 1; i <= 8; i++) {
        double open = ::iOpen(symbol, ltfTimeframe, i);
        double close = ::iClose(symbol, ltfTimeframe, i);
        double high = ::iHigh(symbol, ltfTimeframe, i);
        double low = ::iLow(symbol, ltfTimeframe, i);

        // For a bullish rejection: candle spikes above HTF high and closes below it
        if (high > g_HTFRangeHigh && close < g_HTFRangeHigh) {
            // Check that the upper wick is significant (e.g., >1% of g_HTFRangeHigh)
            if ((high - ::MathMax(open, close)) > (g_HTFRangeHigh * 0.01)) {
                AssignZone(rejZone, "LTF_True_Rej_Bullish", high, low, (datetime)::iTime(symbol, ltfTimeframe, i));
                return true;
            }
        }

        // For a bearish rejection: candle spikes below the HTF low and closes above it.
        if (low < g_HTFRangeLow && close > g_HTFRangeLow) {
            if ((::MathMin(open, close) - low) > (g_HTFRangeLow * 0.01)) {
                AssignZone(rejZone, "LTF_True_Rej_Bearish", high, low, (datetime)::iTime(symbol, ltfTimeframe, i));
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Detect False Confluence Signals                                  |
//+------------------------------------------------------------------+
bool DetectFalseConfluence(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum) {
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    
    // Example false signal: highly exhausted momentum
    int momHandle = ::iMomentum(symbol, ltfTimeframe, 14, PRICE_CLOSE);
    if (momHandle == INVALID_HANDLE) {
        LogError(symbol, "Failed to create Momentum indicator handle");
        return false;
    }
    
    double momValues[];
    if (::CopyBuffer(momHandle, 0, 0, 3, momValues) < 3) {
        LogError(symbol, "Failed to copy Momentum indicator values");
        ::IndicatorRelease(momHandle);
        return false;
    }
    ::IndicatorRelease(momHandle);
    
    // Detect extreme momentum readings (above 110 or below 90)
    if (momValues[0] > 110.0 || momValues[0] < 90.0) {
        LogInfo(symbol, "Extreme Momentum detected, avoiding potential false signal");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Confirm LTF Signal Using Volume Analysis                         |
//+------------------------------------------------------------------+
bool VolumeBasedConfirmation(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum) {
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    
    // Check if current volume is significantly higher than average
    long currentVolume = ::iVolume(symbol, ltfTimeframe, 0);
    int lookback = 20;
    double avgVolume = 0.0;
    
    for (int i = 1; i <= lookback; i++) {
        // ✅ Fixed potential loss of data due to type conversion with explicit cast
        avgVolume += (double)::iVolume(symbol, ltfTimeframe, i);
    }

    avgVolume /= lookback;

    // Explicit cast for currentVolume comparison
    if ((double)currentVolume >= avgVolume * 1.2) {
        LogInfo(symbol, "Volume based confirmation met.");
        return true;
    } else {
        LogInfo(symbol, "Volume based confirmation not met.");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Identify LTF Confluence Elements for Entry Conditions            |
//| with Sweep Direction Consideration and Enhanced Filters          |
//+------------------------------------------------------------------+
bool IdentifyLTFConfluence(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum, bool isBullish) {
    // Use isBullish parameter consistently
    ENUM_TIMEFRAMES ltfTimeframe = ConvertLTFToTimeframe(ltfEnum);
    
    // ✅ Initialize ElementZone objects before use
    ElementZone fvgZone, obZone, rjbZone, pivotZone, rejZone;
    int confluenceCount = 0;
    
    // Each function receives properly initialized ElementZone object reference
    if (DetectLTFStackedFVG(symbol, ltfEnum, fvgZone))
        confluenceCount++;

    if (DetectLTFOrderBlock(symbol, ltfEnum, isBullish, obZone))
        confluenceCount++;

    if (!isBullish) {
        if (DetectLTFRejectionBlock(symbol, ltfEnum, rjbZone))
            confluenceCount++;
    }

    if (DetectPivotBreakout(symbol, ltfEnum, pivotZone))
        confluenceCount++;

    if (DetectTrueRejectionPattern(symbol, ltfEnum, rejZone))
        confluenceCount++;

    // Apply volume-based confirmation as an extra filter
    if (VolumeBasedConfirmation(symbol, ltfEnum))
        confluenceCount++;

    // Filter out signals if false confluence is detected
    if (DetectFalseConfluence(symbol, ltfEnum)) {
        LogInfo(symbol, "False confluence signal detected. Entry filtered.");
        return false;
    }

    // Build a message for confluence count
    string countMsg = ::StringFormat("LTF confluence count: %d", confluenceCount);
    LogInfo(symbol, countMsg);

    if (confluenceCount >= 2) {
        LogInfo(symbol, ::StringFormat("Entry Condition Met - LTF Confluence Achieved with %d elements.", confluenceCount));
        return true;
    }

    LogInfo(symbol, "No Valid LTF Confluence Found.");
    return false;
}

// Add overload with fixed parameter name
bool IdentifyLTFConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBullish) {
    // Convert standard timeframe to LTF enum using the helper function
    ENUM_LTF_TIMEFRAMES ltfEnum = StandardToLTFTimeframe(timeframe);
    return IdentifyLTFConfluence(symbol, ltfEnum, isBullish);
}

#endif  // __IPDA_LTF__
