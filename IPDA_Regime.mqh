��//+------------------------------------------------------------------+
//| IPDA_Regime.mqh - Market regime detection module                 |
//+------------------------------------------------------------------+
#ifndef __IPDA_REGIME__
#define __IPDA_REGIME__

#include "IPDA_ExternalFunctions.mqh"
#include "IPDA_Globals.mqh"
#include "IPDA_Logger.mqh"
#include "IPDA_TimeFrames.mqh"

// Indicator handles
int g_maHandle = INVALID_HANDLE;
int g_adxHandle = INVALID_HANDLE;
int g_atrHandle = INVALID_HANDLE;

// Timeframe tracking for indicator initialization
ENUM_TIMEFRAMES g_lastMATimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_lastADXTimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_lastATRTimeframe = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| Initialize or reinitialize indicators if needed                  |
//+------------------------------------------------------------------+
bool InitializeIndicators(string symbol, ENUM_TIMEFRAMES timeframe) {
    bool result = true;
    
    // Reinitialize MA if timeframe changed or handle is invalid
    if (g_maHandle == INVALID_HANDLE || g_lastMATimeframe != timeframe) {
        if (g_maHandle != INVALID_HANDLE{
            IndicatorRelease(g_maHandle);
        }
        
        g_maHandle = iMA(symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
        if (g_maHandle == INVALID_HANDLE) {
            LogError("REGIME", "Failed to create MA indicator, error: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_lastMATimeframe = timeframe;
        }
    }
    
    // Reinitialize ADX if timeframe changed or handle is invalid
    if (g_adxHandle == INVALID_HANDLE || g_lastADXTimeframe != timeframe) {
        if (g_adxHandle != INVALID_HANDLE) {
            IndicatorRelease(g_adxHandle);
        }
        
        g_adxHandle = iADX(symbol, timeframe, 14);
        if (g_adxHandle == INVALID_HANDLE{
            LogError("REGIME", "Failed to create ADX indicator, error: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_lastADXTimeframe = timeframe;
        }
    }
    
    // Reinitialize ATR if timeframe changed or handle is invalid
    if (g_atrHandle == INVALID_HANDLE || g_lastATRTimeframe != timeframe{
        if (g_atrHandle != INVALID_HANDLE{
            IndicatorRelease(g_atrHandle);
        }
        
        g_atrHandle = iATR(symbol, timeframe, 14);
        if (g_atrHandle == INVALID_HANDLE) {
            LogError("REGIME", "Failed to create ATR indicator, error: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_lastATRTimeframe = timeframe;
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check if indicator data is ready by trying to copy a small amount|
//+------------------------------------------------------------------+
bool IsIndicatorReady(int handle) {
    if (handle == INVALID_HANDLEreturn false;
    
    double buffer[];
    // Try to copy just one value to check if data is ready
    return CopyBuffer(handle, 0, 0, 1, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Wait for indicator data to be ready with timeout                 |
//+------------------------------------------------------------------+
bool WaitForIndicatorData(int handle, int maxAttempts = 5) {
    if (handle == INVALID_HANDLEreturn false;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
        if (IsIndicatorReady(handle)return true;
        // Small sleep between attempts in strategy tester
        Sleep(10);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect market regime based on indicators                         |
//+------------------------------------------------------------------+
MarketRegimeType DetectMarketRegime(string symbol, ENUM_TIMEFRAMES timeframe) {
    // First ensure indicators are initialized
    if (!InitializeIndicators(symbol, timeframe){
        LogError("REGIME", "Failed to initialize indicators for timeframe " + 
                IntegerToString(timeframe));
        return REGIME_RANGE; // Default to range if initialization fails
    }
    
    // Wait for indicator data to be ready
    if (!WaitForIndicatorData(g_maHandle|| 
        !WaitForIndicatorData(g_adxHandle)) {
        LogError("REGIME", "Indicator data not ready for timeframe " + 
                IntegerToString(timeframe));
        return REGIME_RANGE; // Default to range if data not ready
    }
    
    // Copy price data
    double close[];
    if (CopyClose(symbol, timeframe, 0, 3, close) < 3{
        LogError("REGIME", "Failed to copy close prices for timeframe " + 
                IntegerToString(timeframe));
        return REGIME_RANGE;
    }
    
    // Copy MA values
    double ma[];
    if (CopyBuffer(g_maHandle, 0, 0, 3, ma) < 3{
        LogError("REGIME", "Failed to copy MA buffer for timeframe " + 
                IntegerToString(timeframe));
        return REGIME_RANGE;
    }
    
    // Copy ADX values (main line and +DI/-DI)
    double adx[], plusDI[], minusDI[];
    if (CopyBuffer(g_adxHandle, 0, 0, 3, adx) < 3{
        LogError("REGIME", "Failed to copy ADX buffer for timeframe " + 
                IntegerToString(timeframe));
        return REGIME_RANGE;
    }
    
    bool success = true;
    success &= CopyBuffer(g_adxHandle, 1, 0, 3, plusDI>= 3;
    success &= CopyBuffer(g_adxHandle, 2, 0, 3, minusDI>= 3;
    
    if (!success) {
        LogError("REGIME", "Failed to copy ADX +DI/-DI buffers for timeframe " + 
                IntegerToString(timeframe));
        return REGIME_RANGE;
    }
    
    // Analyze regime
    bool isTrending = adx[0] > 25; // ADX > 25 indicates trending market
    bool isPriceAboveMA = close[0] > ma[0];
    bool isPriceGainingMomentum = close[0] > close[1] && close[1] > close[2];
    bool isPriceLosingMomentum = close[0] < close[1] && close[1] < close[2];
    bool isDIPlusStronger = plusDI[0] > minusDI[0];
    
    // Determine regime type
    if (isTrending{
        if (isPriceAboveMA && isDIPlusStronger) {
            return REGIME_TREND_BULL;
        } else if (!isPriceAboveMA && !isDIPlusStronger{
            return REGIME_TREND_BEAR;
        }
    }
    
    // If not clearly trending, assume range
    return REGIME_RANGE;
}

//+------------------------------------------------------------------+
//| Update the market regime for the symbol on specified timeframe   |
//+------------------------------------------------------------------+
bool UpdateMarketRegime(string symbol, ENUM_TIMEFRAMES timeframe, bool updateGlobal = true) {
    // Convert standard timeframe to MQL5 enum if needed
    ENUM_TIMEFRAMES tf = timeframe;
    
    // Get current regime
    MarketRegimeType currentRegime = DetectMarketRegime(symbol, tf);
    
    // Update the appropriate regime info based on timeframe
    if (updateGlobal{
        g_MarketRegime = currentRegime;
    }
    
    // Update the specific timeframe regime info
    RegimeInfo info;
    info.regime = currentRegime;
    info.strength = 0.0; // TODO: Calculate regime strength
    info.lastUpdate = TimeCurrent();
    
    // Store in the appropriate field based on timeframe
    switch (tf{
        case PERIOD_MN1: g_MTFRegimes.Monthly = info; break;
        case PERIOD_W1:  g_MTFRegimes.Weekly = info; break;
        case PERIOD_D1:  g_MTFRegimes.Daily = info; break;
        case PERIOD_H4:  g_MTFRegimes.H4 = info; break;
        case PERIOD_H1:  g_MTFRegimes.H1 = info; break;
        default: 
            // For other timeframes, just update global if requested
            break;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Clean up indicator resources on EA deinitialization              |
//+------------------------------------------------------------------+
void CleanupRegimeIndicators({
    // Release indicator handles to prevent resource leaks
    if (g_maHandle != INVALID_HANDLE) {
        IndicatorRelease(g_maHandle);
        g_maHandle = INVALID_HANDLE;
    }
    
    if (g_adxHandle != INVALID_HANDLE) {
        IndicatorRelease(g_adxHandle);
        g_adxHandle = INVALID_HANDLE;
    }
    
    if (g_atrHandle != INVALID_HANDLE) {
        IndicatorRelease(g_atrHandle);
        g_atrHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Update multiple timeframe regime information                     |
//+------------------------------------------------------------------+
void UpdateMTFRegimes(string symbol{
    LogInfo("REGIME", "Updating multi-timeframe regimes for " + symbol);
    
    // Calculate regime for each timeframe - explicitly cast to prevent timeframe errors
    // Monthly
    CalculateRegimeForTimeframe(symbol, (ENUM_TIMEFRAMES)PERIOD_MN1, g_MTFRegimes.Monthly.regime, g_MTFRegimes.Monthly.strength);
    g_MTFRegimes.Monthly.lastUpdate = TimeCurrent();
    
    // Weekly
    CalculateRegimeForTimeframe(symbol, (ENUM_TIMEFRAMES)PERIOD_W1, g_MTFRegimes.Weekly.regime, g_MTFRegimes.Weekly.strength);
    g_MTFRegimes.Weekly.lastUpdate = TimeCurrent();
    
    // Daily
    CalculateRegimeForTimeframe(symbol, (ENUM_TIMEFRAMES)PERIOD_D1, g_MTFRegimes.Daily.regime, g_MTFRegimes.Daily.strength);
    g_MTFRegimes.Daily.lastUpdate = TimeCurrent();
    
    // H4
    CalculateRegimeForTimeframe(symbol, (ENUM_TIMEFRAMES)PERIOD_H4, g_MTFRegimes.H4.regime, g_MTFRegimes.H4.strength);
    g_MTFRegimes.H4.lastUpdate = TimeCurrent();
    
    // H1
    CalculateRegimeForTimeframe(symbol, (ENUM_TIMEFRAMES)PERIOD_H1, g_MTFRegimes.H1.regime, g_MTFRegimes.H1.strength);
    g_MTFRegimes.H1.lastUpdate = TimeCurrent();
    
    LogInfo("REGIME", "Multi-timeframe regimes updated for " + symbol);
}

//+------------------------------------------------------------------+
//| Calculate regime for a specific timeframe                        |
//+------------------------------------------------------------------+
void CalculateRegimeForTimeframe(string symbol, ENUM_TIMEFRAMES timeframe, MarketRegimeType &regime, double &strength) {
    // Add more detailed logging for debugging
    LogInfo("REGIME", "Calculating regime for timeframe " + TimeframeToString(timeframe));
    
    // Calculate simple trend indicator - 50 EMA vs price
    int maHandle = iMA(symbol, timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE{
        int errorCode = GetLastError();
        LogError("REGIME", "Failed to create MA handle for timeframe " + TimeframeToString(timeframe+ 
                 " - Error: " + IntegerToString(errorCode));
        regime = REGIME_RANGE;  // Default to range on error
        strength = 0.3;
        return;
    }
    
    double maBuffer[];
    if(CopyBuffer(maHandle, 0, 0, 3, maBuffer< 3) {
        int errorCode = GetLastError();
        LogError("REGIME", "Failed to copy MA buffer for timeframe " + TimeframeToString(timeframe) + 
                 " - Error: " + IntegerToString(errorCode));
        IndicatorRelease(maHandle);
        regime = REGIME_RANGE;  // Default to range on error
        strength = 0.3;
        return;
    }
    IndicatorRelease(maHandle);
    
    // Get price data
    double close[];
    if(CopyClose(symbol, timeframe, 0, 3, close) < 3{
        int errorCode = GetLastError();
        LogError("REGIME", "Failed to copy price data for timeframe " + TimeframeToString(timeframe) + 
                 " - Error: " + IntegerToString(errorCode));
        regime = REGIME_RANGE;  // Default to range on error
        strength = 0.3;
        return;
    }
    
    // Determine price position relative to MA and MA direction
    bool priceAboveMA = close[0] > maBuffer[0];
    bool risingMA = maBuffer[0] > maBuffer[2];
    
    // Calculate ADX for trend strength
    int adxHandle = iADX(symbol, timeframe, 14);
    if(adxHandle == INVALID_HANDLE) {
        int errorCode = GetLastError();
        LogError("REGIME", "Failed to create ADX handle for timeframe " + TimeframeToString(timeframe+ 
                 " - Error: " + IntegerToString(errorCode));
        // Still calculate basic regime
        if(priceAboveMA && risingMA{
            regime = REGIME_TREND_BULL;
            strength = 0.6;
        }
        else if(!priceAboveMA && !risingMA{
            regime = REGIME_TREND_BEAR;
            strength = 0.6;
        }
        else {
            regime = REGIME_RANGE;
            strength = 0.7;
        }
        return;
    }
    
    double adxBuffer[];
    if(CopyBuffer(adxHandle, 0, 0, 1, adxBuffer< 1) {
        int errorCode = GetLastError();
        LogError("REGIME", "Failed to copy ADX buffer for timeframe " + TimeframeToString(timeframe+ 
                 " - Error: " + IntegerToString(errorCode));
        IndicatorRelease(adxHandle);
        // Still calculate basic regime
        if(priceAboveMA && risingMA{
            regime = REGIME_TREND_BULL;
            strength = 0.6;
        }
        else if(!priceAboveMA && !risingMA{
            regime = REGIME_TREND_BEAR;
            strength = 0.6;
        }
        else {
            regime = REGIME_RANGE;
            strength = 0.7;
        }
        return;
    }
    IndicatorRelease(adxHandle);
    
    double trendStrength = adxBuffer[0];
    
    // Determine regime based on indicators
    if(trendStrength > 25.0{
        // Strong trend
        if(priceAboveMA && risingMA) {
            regime = REGIME_TREND_BULL;
            strength = trendStrength / 100.0;
        }
        else if(!priceAboveMA && !risingMA) {
            regime = REGIME_TREND_BEAR;
            strength = trendStrength / 100.0;
        }
        else {
            // Mixed signals, consider as range
            regime = REGIME_RANGE;
            strength = 0.5;
        }
    }
    else {
        // Low ADX indicates ranging market
        regime = REGIME_RANGE;
        strength = (25.0 - trendStrength/ 25.0; // Higher strength for lower ADX
    }
    
    LogInfo("REGIME", "Timeframe " + TimeframeToString(timeframe) + " regime calculated: " + 
            (regime == REGIME_TREND_BULL ? "Bullish" : (regime == REGIME_TREND_BEAR ? "Bearish" : "Range")+ 
            ", Strength: " + DoubleToString(strength, 2));
}

//+------------------------------------------------------------------+
//| Visualize the market regime on chart                             |
//+------------------------------------------------------------------+
void VisualizeMarketRegime(string symbol) {
    string regimeName = "IPDA_Regime_" + symbol;
    string regimeStr = "";
    color regimeColor = clrWhite;
    
    // Format regime text and color
    switch(g_MarketRegime) {
        case REGIME_RANGE:
            regimeStr = "RANGE";
            regimeColor = clrYellow;
            break;
        case REGIME_TREND_BULL:
            regimeStr = "BULLISH TREND";
            regimeColor = clrLimeGreen;
            break;
        case REGIME_TREND_BEAR:
            regimeStr = "BEARISH TREND";
            regimeColor = clrRed;
            break;
    }
    
    // Create or update the label
    if(!ObjectFind(0, regimeName)) {
        ObjectCreate(0, regimeName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, regimeName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, regimeName, OBJPROP_YDISTANCE, 20);
        ObjectSetInteger(0, regimeName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    }
    
    ObjectSetString(0, regimeName, OBJPROP_TEXT, "IPDA Regime: " + regimeStr);
    ObjectSetInteger(0, regimeName, OBJPROP_COLOR, regimeColor);
    ObjectSetInteger(0, regimeName, OBJPROP_FONTSIZE, 12);
}

#endif // __IPDA_REGIME__
