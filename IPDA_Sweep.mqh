//+------------------------------------------------------------------+
//| IPDA_Sweep.mqh - Price sweep detection module                    |
//+------------------------------------------------------------------+
#ifndef __IPDA_SWEEP__
#define __IPDA_SWEEP__

#include "IPDA_ExternalFunctions.mqh"
#include "IPDA_Globals.mqh"
#include "IPDA_Logger.mqh"
#include <IPDA_DLLImports.mqh>

// External global variables
extern bool g_SweepDetected;
extern bool g_SweepDirectionBull;
extern datetime g_SweepDetectedTime;
extern double g_SweepDetectedLevel;
extern SweepSignal g_RecentSweep;

//+------------------------------------------------------------------+
//| Detect sweeps of important price levels                          |
//+------------------------------------------------------------------+
bool DetectPriceSweep(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Get the last 3 candles for analysis
    double high[], low[], close[], open[];
    
    if(CopyHigh(symbol, timeframe, 0, 3, high) < 3 ||
       CopyLow(symbol, timeframe, 0, 3, low) < 3 ||
       CopyClose(symbol, timeframe, 0, 3, close) < 3 ||
       CopyOpen(symbol, timeframe, 0, 3, open) < 3) {
        LogError("SWEEP", "Failed to copy price data for sweep detection");
        return false;
    }
    
    // Check for sweep of the IPDA range high
    if(high[0] > g_IPDARange.High && close[0] < g_IPDARange.High) {
        // High has been swept and price closed back below
        g_SweepDetected = true;
        g_SweepDirectionBull = false; // Bearish after high sweep
        g_SweepDetectedTime = TimeCurrent();
        g_SweepDetectedLevel = g_IPDARange.High;
        
        // Fill sweep signal struct
        g_RecentSweep.Valid = true;
        g_RecentSweep.IsBullish = false;
        g_RecentSweep.Time = TimeCurrent();
        g_RecentSweep.Timestamp = TimeCurrent();
        g_RecentSweep.CandleID = iTime(symbol, timeframe, 0);
        g_RecentSweep.Level = g_IPDARange.High;
        g_RecentSweep.Price = close[0];
        g_RecentSweep.Volume = (int)iVolume(symbol, timeframe, 0);
        g_RecentSweep.Intensity = (high[0] - g_IPDARange.High) / _Point;
        
        LogInfo("SWEEP", "Detected HIGH sweep on " + symbol + 
                " at level " + DoubleToString(g_IPDARange.High, _Digits) + 
                ", intensity: " + DoubleToString(g_RecentSweep.Intensity, 1) + " points");
        
        VisualizeSweep(symbol, g_IPDARange.High, false);
        return true;
    }
    
    // Check for sweep of the IPDA range low
    if(low[0] < g_IPDARange.Low && close[0] > g_IPDARange.Low) {
        // Low has been swept and price closed back above
        g_SweepDetected = true;
        g_SweepDirectionBull = true; // Bullish after low sweep
        g_SweepDetectedTime = TimeCurrent();
        g_SweepDetectedLevel = g_IPDARange.Low;
        
        // Fill sweep signal struct
        g_RecentSweep.Valid = true;
        g_RecentSweep.IsBullish = true;
        g_RecentSweep.Time = TimeCurrent();
        g_RecentSweep.Timestamp = TimeCurrent();
        g_RecentSweep.CandleID = iTime(symbol, timeframe, 0);
        g_RecentSweep.Level = g_IPDARange.Low;
        g_RecentSweep.Price = close[0];
        g_RecentSweep.Volume = (int)iVolume(symbol, timeframe, 0);
        g_RecentSweep.Intensity = (g_IPDARange.Low - low[0]) / _Point;
        
        LogInfo("SWEEP", "Detected LOW sweep on " + symbol + 
                " at level " + DoubleToString(g_IPDARange.Low, _Digits) + 
                ", intensity: " + DoubleToString(g_RecentSweep.Intensity, 1) + " points");
        
        VisualizeSweep(symbol, g_IPDARange.Low, true);
        return true;
    }
    
    // Check for mid-level sweep (can indicate range continuation)
    if(high[0] > g_IPDARange.Mid && low[0] < g_IPDARange.Mid) {
        // Midpoint has been crossed
        // Determine direction based on close relative to open
        bool isBullish = close[0] > open[0];
        
        // Only consider it a sweep if it's a strong candle
        double bodySize = MathAbs(close[0] - open[0]);
        double totalSize = high[0] - low[0];
        
        if(bodySize > 0.5 * totalSize) {
            g_SweepDetected = true;
            g_SweepDirectionBull = isBullish;
            g_SweepDetectedTime = TimeCurrent();
            g_SweepDetectedLevel = g_IPDARange.Mid;
            
            // Fill sweep signal struct
            g_RecentSweep.Valid = true;
            g_RecentSweep.IsBullish = isBullish;
            g_RecentSweep.Time = TimeCurrent();
            g_RecentSweep.Timestamp = TimeCurrent();
            g_RecentSweep.CandleID = iTime(symbol, timeframe, 0);
            g_RecentSweep.Level = g_IPDARange.Mid;
            g_RecentSweep.Price = close[0];
            g_RecentSweep.Volume = (int)iVolume(symbol, timeframe, 0);
            g_RecentSweep.Intensity = bodySize / _Point;
            
            LogInfo("SWEEP", "Detected MID sweep on " + symbol + 
                    " at level " + DoubleToString(g_IPDARange.Mid, _Digits) + 
                    ", direction: " + (isBullish ? "Bullish" : "Bearish"));
            
            VisualizeSweep(symbol, g_IPDARange.Mid, isBullish);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if a recent sweep is still valid (not too old)             |
//+------------------------------------------------------------------+
bool IsSweepValid(int maxBarsExpiry) {
    if(!g_SweepDetected) return false;
    
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Calculate time difference in seconds
    int timeDiff = (int)(currentTime - g_SweepDetectedTime);
    
    // Check against expiry time (default H1 bar duration)
    if(timeDiff > PeriodSeconds(PERIOD_H1) * maxBarsExpiry) {
        g_SweepDetected = false;
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Visualize sweep on chart                                         |
//+------------------------------------------------------------------+
void VisualizeSweep(string symbol, double level, bool isBullish) {
    string sweepName = "IPDA_Sweep_" + DoubleToString(level, _Digits) + "_" + symbol;
    string sweepLabelName = sweepName + "_Label";
    
    // Current time for the sweep marker
    datetime sweepTime = TimeCurrent();
    
    // Determine sweep color and direction
    color sweepColor = isBullish ? clrLimeGreen : clrRed;
    string directionText = isBullish ? "↑" : "↓";
    
    // Create sweep marker (vertical line)
    ObjectCreate(0, sweepName, OBJ_VLINE, 0, sweepTime, 0);
    ObjectSetInteger(0, sweepName, OBJPROP_COLOR, sweepColor);
    ObjectSetInteger(0, sweepName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, sweepName, OBJPROP_WIDTH, 2);
    
    // Create sweep label
    ObjectCreate(0, sweepLabelName, OBJ_TEXT, 0, sweepTime, level);
    ObjectSetString(0, sweepLabelName, OBJPROP_TEXT, "SWEEP " + directionText);
    ObjectSetInteger(0, sweepLabelName, OBJPROP_COLOR, sweepColor);
    ObjectSetInteger(0, sweepLabelName, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, sweepLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| LTF confirmation for sweep                                       |
//+------------------------------------------------------------------+
bool ConfirmSweepWithLTF(string symbol, ENUM_LTF_TIMEFRAMES ltfEnum) {
    if(!g_SweepDetected) return false;
    
    // Convert LTF enum to standard timeframe
    ENUM_TIMEFRAMES ltf = ConvertLTFToTimeframe(ltfEnum);
    
    // Get LTF price data
    double close[], high[], low[];
    if(CopyClose(symbol, ltf, 0, 3, close) < 3 ||
       CopyHigh(symbol, ltf, 0, 3, high) < 3 ||
       CopyLow(symbol, ltf, 0, 3, low) < 3) {
        LogError("SWEEP_LTF", "Failed to copy LTF price data");
        return false;
    }
    
    // Check for confirmation candle pattern on LTF
    bool isBullish = g_SweepDirectionBull;
    
    if(isBullish) {
        // For bullish sweep, we want to see a strong bullish candle
        if(close[0] > close[1] && close[0] - low[0] > 0.7 * (high[0] - low[0])) {
            LogInfo("SWEEP_LTF", "LTF confirmed bullish sweep with strong candle");
            return true;
        }
    }
    else {
        // For bearish sweep, we want to see a strong bearish candle
        if(close[0] < close[1] && high[0] - close[0] > 0.7 * (high[0] - low[0])) {
            LogInfo("SWEEP_LTF", "LTF confirmed bearish sweep with strong candle");
            return true;
        }
    }
    
    return false;
}

#endif // __IPDA_SWEEP__
