//+------------------------------------------------------------------+
//| IPDA_EnhancedRegime.mqh - Advanced market regime detection       |
//+------------------------------------------------------------------+
#ifndef __IPDA_ENHANCED_REGIME__
#define __IPDA_ENHANCED_REGIME__

#include "IPDA_ExternalFunctions.mqh"
#include "IPDA_Globals.mqh"
#include "IPDA_Logger.mqh"
#include "IPDA_TimeFrames.mqh"

//+------------------------------------------------------------------+
//| Enhanced Market Regime Enums                                     |
//+------------------------------------------------------------------+
// Primary regime dimensions - more nuanced classification
enum ENUM_MARKET_REGIME_PRIMARY {
    REGIME_TRENDING_STRONG,     // Strong directional movement
    REGIME_TRENDING_WEAK,       // Weak directional movement
    REGIME_RANGING_NARROW,      // Tight consolidation
    REGIME_RANGING_WIDE,        // Wide consolidation
    REGIME_TRANSITIONAL,        // Between regimes
    REGIME_VOLATILE_BREAKOUT,   // High volatility breakout
    REGIME_VOLATILE_REVERSAL    // High volatility reversal
};

// Secondary regime characteristics
struct RegimeCharacteristics {
    double trendStrength;       // 0.0-1.0 measure of trend strength
    double volatility;          // Normalized volatility measurement
    double momentum;            // Momentum measurement (-1.0 to 1.0)
    double marketEfficiency;    // Market efficiency ratio (0.0-1.0)
    double volumeTrend;         // Volume trend measurement (-1.0 to 1.0)
    
    RegimeCharacteristics() {
        trendStrength = 0.0;
        volatility = 0.0;
        momentum = 0.0;
        marketEfficiency = 0.0;
        volumeTrend = 0.0;
    }
};

// Multi-timeframe regime structure
struct EnhancedRegimeInfo {
    ENUM_MARKET_REGIME_PRIMARY regime;
    RegimeCharacteristics characteristics;
    int direction;             // 1 = bullish, -1 = bearish, 0 = neutral
    datetime lastUpdate;
    
    EnhancedRegimeInfo() {
        regime = REGIME_RANGING_NARROW;
        direction = 0;
        lastUpdate = 0;
    }
};

// Enhanced multi-timeframe regime info
struct MTFEnhancedRegimeInfo {
    EnhancedRegimeInfo Monthly;
    EnhancedRegimeInfo Weekly;
    EnhancedRegimeInfo Daily;
    EnhancedRegimeInfo H4;
    EnhancedRegimeInfo H1;
    EnhancedRegimeInfo M15;
};

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
// Indicator handles - renamed to avoid conflicts with other files
int g_enhRegime_maFastHandle = INVALID_HANDLE;
int g_enhRegime_maSlowHandle = INVALID_HANDLE;
int g_enhRegime_adxHandle = INVALID_HANDLE;
int g_enhRegime_atrHandle = INVALID_HANDLE;
int g_enhRegime_macdHandle = INVALID_HANDLE;
int g_enhRegime_stochHandle = INVALID_HANDLE;
int g_enhRegime_mfiHandle = INVALID_HANDLE;
int g_enhRegime_bbandsHandle = INVALID_HANDLE;

// Timeframe tracking for indicator initialization - renamed to avoid conflicts
ENUM_TIMEFRAMES g_enhRegime_lastMAFastTimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_enhRegime_lastMASlowTimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_enhRegime_lastADXTimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_enhRegime_lastATRTimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_enhRegime_lastMACDTimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_enhRegime_lastStochTimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_enhRegime_lastMFITimeframe = PERIOD_CURRENT;
ENUM_TIMEFRAMES g_enhRegime_lastBBandsTimeframe = PERIOD_CURRENT;

// Weights for different timeframes
double tfWeights[6] = {
    0.30,  // Monthly
    0.25,  // Weekly
    0.20,  // Daily
    0.15,  // H4
    0.10,  // H1
    0.05   // M15
};

// Enhanced regime storage
MTFEnhancedRegimeInfo g_EnhancedRegimes;
EnhancedRegimeInfo g_EnhancedRegime; // Single timeframe enhanced regime for current analysis

// Regime change filter for whipsaw protection
class RegimeChangeFilter {
private:
    ENUM_MARKET_REGIME_PRIMARY m_currentRegime;
    ENUM_MARKET_REGIME_PRIMARY m_pendingRegime;
    int m_confirmationBars;
    int m_requiredBars;
    double m_volatility;
    
public:
    RegimeChangeFilter() {
        m_currentRegime = REGIME_RANGING_NARROW;
        m_pendingRegime = REGIME_RANGING_NARROW;
        m_confirmationBars = 0;
        m_requiredBars = 2;
        m_volatility = 1.0;
    }
    
    // Update regime signal with confirmation logic
    ENUM_MARKET_REGIME_PRIMARY UpdateRegimeSignal(ENUM_MARKET_REGIME_PRIMARY newSignal, double volatility) {
        // Adjust required bars based on volatility
        m_volatility = volatility;
        m_requiredBars = (int)MathMax(2, MathRound(2 + volatility * 3));
        
        if (newSignal == m_pendingRegime) {
            m_confirmationBars++;
        } else {
            m_pendingRegime = newSignal;
            m_confirmationBars = 1;
        }
        
        // Return current regime
        if (m_confirmationBars >= m_requiredBars) {
            m_currentRegime = m_pendingRegime;
            m_confirmationBars = 0;
        }
        
        return m_currentRegime;
    }
    
    ENUM_MARKET_REGIME_PRIMARY GetCurrentRegime() {
        return m_currentRegime;
    }
};

// Global regime filter
RegimeChangeFilter g_RegimeFilter;

//+------------------------------------------------------------------+
//| Initialize or reinitialize indicators if needed                  |
//+------------------------------------------------------------------+
bool InitializeEnhancedIndicators(string symbol, ENUM_TIMEFRAMES timeframe) {
    bool result = true;
    
    // Fast MA (20 EMA)
    if (g_enhRegime_maFastHandle == INVALID_HANDLE || g_enhRegime_lastMAFastTimeframe != timeframe) {
        if (g_enhRegime_maFastHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_maFastHandle);
        
        g_enhRegime_maFastHandle = iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
        if (g_enhRegime_maFastHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create Fast MA indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastMAFastTimeframe = timeframe;
        }
    }
    
    // Slow MA (50 SMA)
    if (g_enhRegime_maSlowHandle == INVALID_HANDLE || g_enhRegime_lastMASlowTimeframe != timeframe) {
        if (g_enhRegime_maSlowHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_maSlowHandle);
        
        g_enhRegime_maSlowHandle = iMA(symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
        if (g_enhRegime_maSlowHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create Slow MA indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastMASlowTimeframe = timeframe;
        }
    }
    
    // ADX
    if (g_enhRegime_adxHandle == INVALID_HANDLE || g_enhRegime_lastADXTimeframe != timeframe) {
        if (g_enhRegime_adxHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_adxHandle);
        
        g_enhRegime_adxHandle = iADX(symbol, timeframe, 14);
        if (g_enhRegime_adxHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create ADX indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastADXTimeframe = timeframe;
        }
    }
    
    // ATR
    if (g_enhRegime_atrHandle == INVALID_HANDLE || g_enhRegime_lastATRTimeframe != timeframe) {
        if (g_enhRegime_atrHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_atrHandle);
        
        g_enhRegime_atrHandle = iATR(symbol, timeframe, 14);
        if (g_enhRegime_atrHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create ATR indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastATRTimeframe = timeframe;
        }
    }
    
    // MACD
    if (g_enhRegime_macdHandle == INVALID_HANDLE || g_enhRegime_lastMACDTimeframe != timeframe) {
        if (g_enhRegime_macdHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_macdHandle);
        
        g_enhRegime_macdHandle = iMACD(symbol, timeframe, 12, 26, 9, PRICE_CLOSE);
        if (g_enhRegime_macdHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create MACD indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastMACDTimeframe = timeframe;
        }
    }
    
    // Stochastic
    if (g_enhRegime_stochHandle == INVALID_HANDLE || g_enhRegime_lastStochTimeframe != timeframe) {
        if (g_enhRegime_stochHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_stochHandle);
        
        g_enhRegime_stochHandle = iStochastic(symbol, timeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
        if (g_enhRegime_stochHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create Stochastic indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastStochTimeframe = timeframe;
        }
    }
    
    // MFI
    if (g_enhRegime_mfiHandle == INVALID_HANDLE || g_enhRegime_lastMFITimeframe != timeframe) {
        if (g_enhRegime_mfiHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_mfiHandle);
        
        g_enhRegime_mfiHandle = iMFI(symbol, timeframe, 14, VOLUME_TICK);
        if (g_enhRegime_mfiHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create MFI indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastMFITimeframe = timeframe;
        }
    }
    
    // Bollinger Bands
    if (g_enhRegime_bbandsHandle == INVALID_HANDLE || g_enhRegime_lastBBandsTimeframe != timeframe) {
        if (g_enhRegime_bbandsHandle != INVALID_HANDLE) IndicatorRelease(g_enhRegime_bbandsHandle);
        
        g_enhRegime_bbandsHandle = iBands(symbol, timeframe, 20, 0, 2.0, PRICE_CLOSE);
        if (g_enhRegime_bbandsHandle == INVALID_HANDLE) {
            LogError("REGIME+", "Failed to create Bollinger Bands indicator: " + IntegerToString(GetLastError()));
            result = false;
        } else {
            g_enhRegime_lastBBandsTimeframe = timeframe;
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check if indicator data is ready with timeout                    |
//+------------------------------------------------------------------+
bool EnhancedRegimeWaitForIndicatorData(int handle, int maxAttempts = 5) {
    if (handle == INVALID_HANDLE) return false;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
        double buffer[];
        if (CopyBuffer(handle, 0, 0, 1, buffer) > 0) return true;
        Sleep(10); // Wait briefly between attempts
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate normalized value within range                          |
//+------------------------------------------------------------------+
double NormalizeValue(double value, double minValue, double maxValue) {
    if (value <= minValue) return 0.0;
    if (value >= maxValue) return 1.0;
    return (value - minValue) / (maxValue - minValue);
}

//+------------------------------------------------------------------+
//| Normalize indicator by volatility                                |
//+------------------------------------------------------------------+
double NormalizeByVolatility(double value, double atr14, double atrLongTerm) {
    if (atr14 <= 0 || atrLongTerm <= 0) return value;
    // Normalized value relative to both short and long-term volatility
    return value / (atr14 * (0.5 + 0.5 * (atr14 / atrLongTerm)));
}

//+------------------------------------------------------------------+
//| Calculate Market Efficiency Ratio (MER)                          |
//+------------------------------------------------------------------+
double CalculateMarketEfficiencyRatio(string symbol, ENUM_TIMEFRAMES timeframe, int period = 14) {
    double direction = 0.0;
    double volatility = 0.0;
    
    // Get price data
    double close[];
    if (CopyClose(symbol, timeframe, 0, period + 1, close) < period + 1) {
        return 0.5; // Default value if data isn't available
    }
    
    // Calculate net direction (end price - start price)
    direction = MathAbs(close[0] - close[period]);
    
    // Calculate volatility (sum of absolute price changes)
    for (int i = 0; i < period; i++) {
        volatility += MathAbs(close[i] - close[i + 1]);
    }
    
    // Avoid division by zero
    if (volatility == 0) return 0.5;
    
    // MER = Direction / Volatility
    return direction / volatility;
}

//+------------------------------------------------------------------+
//| Calculate regime characteristics for a timeframe                 |
//+------------------------------------------------------------------+
RegimeCharacteristics CalculateRegimeCharacteristics(string symbol, ENUM_TIMEFRAMES timeframe) {
    RegimeCharacteristics result;
    
    // Ensure indicators are initialized
    if (!InitializeEnhancedIndicators(symbol, timeframe)) {
        LogError("REGIME+", "Failed to initialize indicators for characteristics calculation");
        return result;
    }
    
    // Wait for indicator data
    bool indicatorsReady = 
        EnhancedRegimeWaitForIndicatorData(g_enhRegime_maFastHandle) &&
        EnhancedRegimeWaitForIndicatorData(g_enhRegime_maSlowHandle) &&
        EnhancedRegimeWaitForIndicatorData(g_enhRegime_adxHandle) &&
        EnhancedRegimeWaitForIndicatorData(g_enhRegime_atrHandle) &&
        EnhancedRegimeWaitForIndicatorData(g_enhRegime_macdHandle) &&
        EnhancedRegimeWaitForIndicatorData(g_enhRegime_stochHandle);
    
    if (!indicatorsReady) {
        LogError("REGIME+", "Indicator data not ready for characteristics calculation");
        return result;
    }
    
    // Copy price data
    double close[];
    if (CopyClose(symbol, timeframe, 0, 5, close) < 5) {
        LogError("REGIME+", "Failed to copy price data for characteristics calculation");
        return result;
    }
    
    // Copy MA values
    double maFast[], maSlow[];
    if (CopyBuffer(g_enhRegime_maFastHandle, 0, 0, 5, maFast) < 5 || 
        CopyBuffer(g_enhRegime_maSlowHandle, 0, 0, 5, maSlow) < 5) {
        LogError("REGIME+", "Failed to copy MA data for characteristics calculation");
        return result;
    }
    
    // Copy ADX values
    double adx[], plusDI[], minusDI[];
    if (CopyBuffer(g_enhRegime_adxHandle, 0, 0, 5, adx) < 5 ||
        CopyBuffer(g_enhRegime_adxHandle, 1, 0, 5, plusDI) < 5 ||
        CopyBuffer(g_enhRegime_adxHandle, 2, 0, 5, minusDI) < 5) {
        LogError("REGIME+", "Failed to copy ADX data for characteristics calculation");
        return result;
    }
    
    // Copy ATR values
    double atr[], atrLong[];
    if (CopyBuffer(g_enhRegime_atrHandle, 0, 0, 5, atr) < 5) {
        LogError("REGIME+", "Failed to copy ATR data for characteristics calculation");
        return result;
    }
    
    // Calculate ATR ratio (current vs. long term)
    double atrValue = atr[0];
    double atrLongValue = 0.0;
    
    int atrLongHandle = iATR(symbol, timeframe, 50);
    if (atrLongHandle != INVALID_HANDLE) {
        if (CopyBuffer(atrLongHandle, 0, 0, 1, atrLong) > 0) {
            atrLongValue = atrLong[0];
        }
        IndicatorRelease(atrLongHandle);
    }
    
    if (atrLongValue <= 0) atrLongValue = atrValue; // Fallback
    
    // Copy MACD values
    double macdMain[], macdSignal[];
    if (CopyBuffer(g_enhRegime_macdHandle, 0, 0, 5, macdMain) < 5 ||
        CopyBuffer(g_enhRegime_macdHandle, 1, 0, 5, macdSignal) < 5) {
        LogError("REGIME+", "Failed to copy MACD data for characteristics calculation");
        return result;
    }
    
    // Copy Stochastic values
    double stochMain[], stochSignal[];
    if (CopyBuffer(g_enhRegime_stochHandle, 0, 0, 5, stochMain) < 5 ||
        CopyBuffer(g_enhRegime_stochHandle, 1, 0, 5, stochSignal) < 5) {
        LogError("REGIME+", "Failed to copy Stochastic data for characteristics calculation");
        return result;
    }
    
    // Copy MFI values if available
    double mfi[1] = {50.0}; // Default value
    if (g_enhRegime_mfiHandle != INVALID_HANDLE) {
        CopyBuffer(g_enhRegime_mfiHandle, 0, 0, 1, mfi);
    }
    
    // Calculate trend strength (ADX, MA relationship)
    double adxStrength = NormalizeValue(adx[0], 10, 50);
    double maRelationship = 0.0;
    
    if (maFast[0] > maSlow[0] && maFast[1] > maSlow[1]) {
        maRelationship = 0.7; // Strong uptrend
    } else if (maFast[0] < maSlow[0] && maFast[1] < maSlow[1]) {
        maRelationship = 0.7; // Strong downtrend
    } else if (maFast[0] > maSlow[0] && maFast[1] < maSlow[1]) {
        maRelationship = 0.4; // New uptrend
    } else if (maFast[0] < maSlow[0] && maFast[1] > maSlow[1]) {
        maRelationship = 0.4; // New downtrend
    } else {
        maRelationship = 0.2; // Flat
    }
    
    result.trendStrength = (adxStrength * 0.6) + (maRelationship * 0.4);
    
    // Calculate volatility
    double atrRatio = atrLongValue > 0 ? atrValue / atrLongValue : 1.0;
    result.volatility = NormalizeValue(atrRatio, 0.5, 2.0);
    
    // Calculate momentum
    double macdHistogram = macdMain[0] - macdSignal[0];
    double macdHistPrev = macdMain[1] - macdSignal[1];
    double momentumChange = macdHistogram - macdHistPrev;
    
    double stochMomentum = 0.0;
    if (stochMain[0] > 80 || stochMain[0] < 20) {
        stochMomentum = (stochMain[0] - 50) / 50.0; // -1.0 to 1.0
    } else {
        stochMomentum = (stochMain[0] - 50) / 100.0; // -0.5 to 0.5
    }
    
    if (stochMain[0] > stochMain[1]) {
        stochMomentum = MathAbs(stochMomentum);
    } else {
        stochMomentum = -MathAbs(stochMomentum);
    }
    
    result.momentum = stochMomentum * 0.4 + (momentumChange > 0 ? 0.3 : -0.3) + (macdHistogram > 0 ? 0.3 : -0.3);
    result.momentum = MathMax(-1.0, MathMin(1.0, result.momentum));
    
    // Calculate market efficiency
    result.marketEfficiency = CalculateMarketEfficiencyRatio(symbol, timeframe);
    
    // Calculate volume trend
    result.volumeTrend = (mfi[0] - 50) / 50.0; // -1.0 to 1.0
    
    return result;
}

//+------------------------------------------------------------------+
//| Detect market regime for a timeframe                             |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME_PRIMARY DetectEnhancedRegime(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Calculate characteristics first
    RegimeCharacteristics chars = CalculateRegimeCharacteristics(symbol, timeframe);
    
    // Apply regime detection logic
    ENUM_MARKET_REGIME_PRIMARY regimeSignal;
    
    // Check for high volatility regimes first
    if (chars.volatility > 0.8) {
        if (chars.momentum > 0.7) {
            regimeSignal = REGIME_VOLATILE_BREAKOUT;
        } 
        else if (chars.momentum < -0.7) {
            regimeSignal = REGIME_VOLATILE_REVERSAL;
        }
        else {
            regimeSignal = REGIME_TRANSITIONAL;
        }
    }
    // Check for trending regimes
    else if (chars.trendStrength > 0.7) {
        regimeSignal = REGIME_TRENDING_STRONG;
    }
    else if (chars.trendStrength > 0.4) {
        regimeSignal = REGIME_TRENDING_WEAK;
    }
    // Check for ranging regimes
    else if (chars.volatility < 0.4) {
        regimeSignal = REGIME_RANGING_NARROW;
    }
    else {
        regimeSignal = REGIME_RANGING_WIDE;
    }
    
    // Apply whipsaw protection
    return g_RegimeFilter.UpdateRegimeSignal(regimeSignal, chars.volatility);
}

//+------------------------------------------------------------------+
//| Clean up indicator resources                                     |
//+------------------------------------------------------------------+
void CleanupEnhancedRegimeIndicators() {
    if (g_enhRegime_maFastHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_maFastHandle);
        g_enhRegime_maFastHandle = INVALID_HANDLE;
    }
    
    if (g_enhRegime_maSlowHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_maSlowHandle);
        g_enhRegime_maSlowHandle = INVALID_HANDLE;
    }
    
    if (g_enhRegime_adxHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_adxHandle);
        g_enhRegime_adxHandle = INVALID_HANDLE;
    }
    
    if (g_enhRegime_atrHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_atrHandle);
        g_enhRegime_atrHandle = INVALID_HANDLE;
    }
    
    if (g_enhRegime_macdHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_macdHandle);
        g_enhRegime_macdHandle = INVALID_HANDLE;
    }
    
    if (g_enhRegime_stochHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_stochHandle);
        g_enhRegime_stochHandle = INVALID_HANDLE;
    }
    
    if (g_enhRegime_mfiHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_mfiHandle);
        g_enhRegime_mfiHandle = INVALID_HANDLE;
    }
    
    if (g_enhRegime_bbandsHandle != INVALID_HANDLE) {
        IndicatorRelease(g_enhRegime_bbandsHandle);
        g_enhRegime_bbandsHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Determine market direction based on regime and indicators        |
//+------------------------------------------------------------------+
int DetermineMarketDirection(string symbol, ENUM_TIMEFRAMES timeframe, ENUM_MARKET_REGIME_PRIMARY regime) {
    // Ensure indicators are initialized
    if (!InitializeEnhancedIndicators(symbol, timeframe)) {
        LogError("REGIME+", "Failed to initialize indicators for direction determination");
        return 0; // Neutral on error
    }
    
    // Get basic direction indicators
    bool priceAboveMA = false;
    bool risingMA = false;
    double momentumDirection = 0.0;
    double volumeForceDirection = 0.0;
    
    // Copy price data
    double close[];
    if (CopyClose(symbol, timeframe, 0, 3, close) < 3) {
        LogError("REGIME+", "Failed to copy price data for direction determination");
        return 0;
    }
    
    // Copy MA values
    double maFast[], maSlow[];
    if (CopyBuffer(g_enhRegime_maFastHandle, 0, 0, 3, maFast) < 3 || 
        CopyBuffer(g_enhRegime_maSlowHandle, 0, 0, 3, maSlow) < 3) {
        LogError("REGIME+", "Failed to copy MA data for direction determination");
        return 0;
    }
    
    // Calculate basic direction indicators
    priceAboveMA = close[0] > maSlow[0];
    risingMA = maSlow[0] > maSlow[2];
    
    // Copy MACD for momentum
    double macdMain[], macdSignal[];
    if (CopyBuffer(g_enhRegime_macdHandle, 0, 0, 2, macdMain) < 2 ||
        CopyBuffer(g_enhRegime_macdHandle, 1, 0, 2, macdSignal) < 2) {
        LogError("REGIME+", "Failed to copy MACD data for direction determination");
        return 0;
    }
    
    // Calculate momentum direction
    double macdHistogram = macdMain[0] - macdSignal[0];
    double macdHistPrev = macdMain[1] - macdSignal[1];
    momentumDirection = macdHistogram > 0 ? 1.0 : -1.0;
    
    // Check volume force if MFI indicator is available
    if (g_enhRegime_mfiHandle != INVALID_HANDLE) {
        double mfi[];
        if (CopyBuffer(g_enhRegime_mfiHandle, 0, 0, 2, mfi) >= 2) {
            volumeForceDirection = mfi[0] > 50 ? 1.0 : -1.0;
        }
    }
    
    // Different regimes require different directional signals
    switch(regime) {
        case REGIME_TRENDING_STRONG:
            // In strong trends, price position and momentum matter most
            return (priceAboveMA && momentumDirection > 0) ? 1 : 
                   (!priceAboveMA && momentumDirection < 0) ? -1 : 0;
        
        case REGIME_TRENDING_WEAK:
            // In weak trends, need more confirmation
            if (priceAboveMA && risingMA && momentumDirection > 0)
                return 1;
            else if (!priceAboveMA && !risingMA && momentumDirection < 0)
                return -1;
            else
                return 0;
            
        case REGIME_VOLATILE_BREAKOUT:
            // In breakouts, volume and momentum are key
            return (momentumDirection > 0 && volumeForceDirection > 0) ? 1 :
                   (momentumDirection < 0 && volumeForceDirection < 0) ? -1 : 0;
        
        case REGIME_VOLATILE_REVERSAL:
            // In reversals, look for counter-trend signals
            return (momentumDirection > 0 && !priceAboveMA) ? 1 :
                   (momentumDirection < 0 && priceAboveMA) ? -1 : 0;
        
        case REGIME_RANGING_NARROW:
            // In tight ranges, mean reversion signals matter more
            return (priceAboveMA && !risingMA) ? -1 :  // Potential top
                   (!priceAboveMA && risingMA) ? 1 : 0;  // Potential bottom
                   
        case REGIME_RANGING_WIDE:
            {  // Adding curly braces to create proper scope for the variable
                // In wide ranges, look for clear extremes
                // Check if near band edges with stochastic confirmation
                double stochMain[];
                if (CopyBuffer(g_enhRegime_stochHandle, 0, 0, 1, stochMain) < 1) {
                    return 0;
                }
                
                if (stochMain[0] < 20 && !priceAboveMA)
                    return 1;  // Potential bottom of range
                else if (stochMain[0] > 80 && priceAboveMA)
                    return -1; // Potential top of range
                else
                    return 0;
            }
                
        case REGIME_TRANSITIONAL:
            // In transitional phases, wait for clearer signals
            if (priceAboveMA && risingMA && momentumDirection > 0 && volumeForceDirection > 0)
                return 1;  // Strong bullish confirmation
            else if (!priceAboveMA && !risingMA && momentumDirection < 0 && volumeForceDirection < 0)
                return -1; // Strong bearish confirmation
            else
                return 0;  // Not enough confirmation
            
        default:
            // Default direction calculation
            return (priceAboveMA && risingMA) ? 1 :
                   (!priceAboveMA && !risingMA) ? -1 : 0;
    }
}

//+------------------------------------------------------------------+
//| Trade Parameters structure for regime-based adaptations          |
//+------------------------------------------------------------------+
struct TradeParameters {
    double stopMultiplier;        // ATR multiplier for stop loss
    double targetMultiplier;      // Reward:risk ratio
    double counterTrendFilter;    // Threshold for counter-trend signals (0.0-1.0)
    double entryAggressiveness;   // How aggressively to enter trades (0.0-1.0)
    int preferredDirection;       // 1=bullish, -1=bearish, 0=both
    bool allowBreakouts;          // Whether to take breakout trades
    bool allowRangeReversals;     // Whether to take range reversal trades
    
    TradeParameters() {
        stopMultiplier = 1.5;
        targetMultiplier = 2.0;
        counterTrendFilter = 0.5;
        entryAggressiveness = 0.5;
        preferredDirection = 0;
        allowBreakouts = true;
        allowRangeReversals = true;
    }
};

//+------------------------------------------------------------------+
//| Adapt trading strategy based on regime                           |
//+------------------------------------------------------------------+
void AdaptStrategyToRegime(ENUM_MARKET_REGIME_PRIMARY regime, int direction, TradeParameters &params) {
    // Reset parameters to defaults
    params.stopMultiplier = 1.5;
    params.targetMultiplier = 2.0;
    params.counterTrendFilter = 0.5;
    params.entryAggressiveness = 0.5;
    params.allowBreakouts = true;
    params.allowRangeReversals = true;
    
    // Adapt based on regime
    switch(regime) {
        case REGIME_TRENDING_STRONG:
            // In strong trends: wider stops, larger targets, prefer with-trend trades
            params.stopMultiplier = 1.5;
            params.targetMultiplier = 3.0;
            params.counterTrendFilter = 0.9;  // Very high threshold for counter-trend
            params.entryAggressiveness = 0.8; // Don't wait for deep pullbacks
            params.allowBreakouts = true;
            params.allowRangeReversals = false; // No reversals in strong trend
            break;
            
        case REGIME_TRENDING_WEAK:
            // In weak trends: moderate stops, good targets, some pullbacks
            params.stopMultiplier = 1.3;
            params.targetMultiplier = 2.5;
            params.counterTrendFilter = 0.7;  
            params.entryAggressiveness = 0.6; 
            params.allowBreakouts = true;
            params.allowRangeReversals = false;
            break;
            
        case REGIME_RANGING_NARROW:
            // In tight ranges: tighter stops, modest targets, mean-reversion
            params.stopMultiplier = 1.0;
            params.targetMultiplier = 1.5;
            params.counterTrendFilter = 0.3;  // Lower threshold for counter-trend (mean reversion)
            params.entryAggressiveness = 0.4; // Wait for range extremes
            params.allowBreakouts = false;    // No breakouts in tight range
            params.allowRangeReversals = true;
            break;
            
        case REGIME_RANGING_WIDE:
            // In wide ranges: moderate stops for wider swings
            params.stopMultiplier = 1.2;
            params.targetMultiplier = 1.8;
            params.counterTrendFilter = 0.4;
            params.entryAggressiveness = 0.5;
            params.allowBreakouts = false;
            params.allowRangeReversals = true;
            break;
            
        case REGIME_VOLATILE_BREAKOUT:
            // In breakouts: delayed entries, wider stops
            params.stopMultiplier = 2.0;
            params.targetMultiplier = 2.5;
            params.counterTrendFilter = 0.7;
            params.entryAggressiveness = 0.6; // Wait for breakout confirmation
            params.allowBreakouts = true;
            params.allowRangeReversals = false;
            break;
            
        case REGIME_VOLATILE_REVERSAL:
            // In reversals: careful entries, moderate stops
            params.stopMultiplier = 1.7;
            params.targetMultiplier = 2.2;
            params.counterTrendFilter = 0.5;
            params.entryAggressiveness = 0.3; // Careful entries in reversals
            params.allowBreakouts = false;
            params.allowRangeReversals = true;
            break;
            
        case REGIME_TRANSITIONAL:
            // In transitions: conservative approach
            params.stopMultiplier = 1.7;
            params.targetMultiplier = 2.0;
            params.counterTrendFilter = 0.6;
            params.entryAggressiveness = 0.4;
            params.allowBreakouts = false;
            params.allowRangeReversals = false;
            break;
    }
    
    // Adjust for direction if specified
    if (direction != 0) {
        params.preferredDirection = direction;
    }
    
    // Log the strategy adaptations
    string regimeStr;
    switch(regime) {
        case REGIME_TRENDING_STRONG: regimeStr = "Strong Trend"; break;
        case REGIME_TRENDING_WEAK: regimeStr = "Weak Trend"; break;
        case REGIME_RANGING_NARROW: regimeStr = "Tight Range"; break;
        case REGIME_RANGING_WIDE: regimeStr = "Wide Range"; break;
        case REGIME_VOLATILE_BREAKOUT: regimeStr = "Breakout"; break;
        case REGIME_VOLATILE_REVERSAL: regimeStr = "Reversal"; break;
        case REGIME_TRANSITIONAL: regimeStr = "Transitional"; break;
        default: regimeStr = "Unknown";
    }
    
    string directionStr = (direction > 0) ? "Bullish" : ((direction < 0) ? "Bearish" : "Neutral");
    
    LogInfo("STRATEGY", "Adapted to " + regimeStr + " regime (" + directionStr + 
            ") - Stop: " + DoubleToString(params.stopMultiplier, 1) + 
            "x, Target: " + DoubleToString(params.targetMultiplier, 1) + 
            "x, Aggressiveness: " + DoubleToString(params.entryAggressiveness, 1));
}

//+------------------------------------------------------------------+
//| Update multi-timeframe enhanced regimes                          |
//+------------------------------------------------------------------+
void UpdateAllEnhancedRegimes(string symbol) {
    // Monthly timeframe
    UpdateEnhancedRegimeForTimeframe(symbol, PERIOD_MN1, g_EnhancedRegimes.Monthly);
    
    // Weekly timeframe
    UpdateEnhancedRegimeForTimeframe(symbol, PERIOD_W1, g_EnhancedRegimes.Weekly);
    
    // Daily timeframe
    UpdateEnhancedRegimeForTimeframe(symbol, PERIOD_D1, g_EnhancedRegimes.Daily);
    
    // H4 timeframe
    UpdateEnhancedRegimeForTimeframe(symbol, PERIOD_H4, g_EnhancedRegimes.H4);
    
    // H1 timeframe
    UpdateEnhancedRegimeForTimeframe(symbol, PERIOD_H1, g_EnhancedRegimes.H1);
    
    // M15 timeframe
    UpdateEnhancedRegimeForTimeframe(symbol, PERIOD_M15, g_EnhancedRegimes.M15);
    
    LogInfo("REGIME+", "All timeframe regimes updated for " + symbol);
}

//+------------------------------------------------------------------+
//| Update enhanced regime for a specific timeframe                  |
//+------------------------------------------------------------------+
void UpdateEnhancedRegimeForTimeframe(string symbol, ENUM_TIMEFRAMES timeframe, EnhancedRegimeInfo &info) {
    // Detect regime
    info.regime = DetectEnhancedRegime(symbol, timeframe);
    
    // Calculate characteristics
    info.characteristics = CalculateRegimeCharacteristics(symbol, timeframe);
    
    // Determine market direction
    info.direction = DetermineMarketDirection(symbol, timeframe, info.regime);
    
    // Update timestamp
    info.lastUpdate = TimeCurrent();
    
    // Log the update
    string timeframeStr = GetTimeframeName(timeframe);
    string regimeStr = GetEnhancedRegimeString(info.regime);
    string directionStr = (info.direction > 0) ? "Bullish" : ((info.direction < 0) ? "Bearish" : "Neutral");
    
    LogInfo("REGIME+", timeframeStr + ": " + regimeStr + " (" + directionStr + 
            ") - Trend: " + DoubleToString(info.characteristics.trendStrength, 2) + 
            ", Vol: " + DoubleToString(info.characteristics.volatility, 2));
}

//+------------------------------------------------------------------+
//| Get string representation of enhanced regime type                |
//+------------------------------------------------------------------+
string GetEnhancedRegimeString(ENUM_MARKET_REGIME_PRIMARY regime) {
    switch(regime) {
        case REGIME_TRENDING_STRONG: return "Strong Trend";
        case REGIME_TRENDING_WEAK: return "Weak Trend";
        case REGIME_RANGING_NARROW: return "Tight Range";
        case REGIME_RANGING_WIDE: return "Wide Range";
        case REGIME_TRANSITIONAL: return "Transitional";
        case REGIME_VOLATILE_BREAKOUT: return "Breakout";
        case REGIME_VOLATILE_REVERSAL: return "Reversal";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Get enhanced multi-timeframe confluence analysis                 |
//+------------------------------------------------------------------+
EnhancedRegimeInfo GetConfluenceRegime(string symbol) {
    EnhancedRegimeInfo result;
    result.regime = REGIME_TRANSITIONAL; // Default
    
    // Calculate weighted direction score
    double directionScore = 0.0;
    directionScore += g_EnhancedRegimes.Monthly.direction * tfWeights[0];
    directionScore += g_EnhancedRegimes.Weekly.direction * tfWeights[1];
    directionScore += g_EnhancedRegimes.Daily.direction * tfWeights[2];
    directionScore += g_EnhancedRegimes.H4.direction * tfWeights[3];
    directionScore += g_EnhancedRegimes.H1.direction * tfWeights[4];
    directionScore += g_EnhancedRegimes.M15.direction * tfWeights[5];
    
    // Set direction based on weighted score
    if (directionScore > 0.2) result.direction = 1;  // Bullish
    else if (directionScore < -0.2) result.direction = -1; // Bearish
    else result.direction = 0; // Neutral
    
    // Weighted trend strength
    result.characteristics.trendStrength = 
        g_EnhancedRegimes.Monthly.characteristics.trendStrength * tfWeights[0] +
        g_EnhancedRegimes.Weekly.characteristics.trendStrength * tfWeights[1] +
        g_EnhancedRegimes.Daily.characteristics.trendStrength * tfWeights[2] +
        g_EnhancedRegimes.H4.characteristics.trendStrength * tfWeights[3] +
        g_EnhancedRegimes.H1.characteristics.trendStrength * tfWeights[4] +
        g_EnhancedRegimes.M15.characteristics.trendStrength * tfWeights[5];
    
    // Weighted volatility
    result.characteristics.volatility = 
        g_EnhancedRegimes.Monthly.characteristics.volatility * tfWeights[0] +
        g_EnhancedRegimes.Weekly.characteristics.volatility * tfWeights[1] +
        g_EnhancedRegimes.Daily.characteristics.volatility * tfWeights[2] +
        g_EnhancedRegimes.H4.characteristics.volatility * tfWeights[3] +
        g_EnhancedRegimes.H1.characteristics.volatility * tfWeights[4] +
        g_EnhancedRegimes.M15.characteristics.volatility * tfWeights[5];
    
    // Weighted momentum - gives more weight to shorter timeframes
    result.characteristics.momentum = 
        g_EnhancedRegimes.Monthly.characteristics.momentum * 0.05 +
        g_EnhancedRegimes.Weekly.characteristics.momentum * 0.1 +
        g_EnhancedRegimes.Daily.characteristics.momentum * 0.15 +
        g_EnhancedRegimes.H4.characteristics.momentum * 0.2 +
        g_EnhancedRegimes.H1.characteristics.momentum * 0.25 +
        g_EnhancedRegimes.M15.characteristics.momentum * 0.25;
    
    // Determine overall regime based on characteristics
    if (result.characteristics.trendStrength > 0.7) {
        result.regime = REGIME_TRENDING_STRONG;
    }
    else if (result.characteristics.trendStrength > 0.4) {
        result.regime = REGIME_TRENDING_WEAK;
    }
    else if (result.characteristics.volatility > 0.8) {
        if (result.characteristics.momentum > 0.5) {
            result.regime = REGIME_VOLATILE_BREAKOUT;
        } 
        else if (result.characteristics.momentum < -0.5) {
            result.regime = REGIME_VOLATILE_REVERSAL;
        }
        else {
            result.regime = REGIME_TRANSITIONAL;
        }
    }
    else if (result.characteristics.volatility < 0.4) {
        result.regime = REGIME_RANGING_NARROW;
    }
    else {
        result.regime = REGIME_RANGING_WIDE;
    }
    
    result.lastUpdate = TimeCurrent();
    
    return result;
}

//+------------------------------------------------------------------+
//| Visualize market regime on chart                                 |
//+------------------------------------------------------------------+
void VisualizeEnhancedRegime(string symbol) {
    // Get current regime and direction
    EnhancedRegimeInfo confluenceRegime = GetConfluenceRegime(symbol);
    
    // Define object names
    string regimeLabelName = "IPDA_Enhanced_Regime_" + symbol;
    string regimeBoxName = "IPDA_Enhanced_Regime_Box_" + symbol;
    string directionName = "IPDA_Direction_" + symbol;
    string characteristicsName = "IPDA_Characteristics_" + symbol;
    
    // Format regime text and determine color
    string regimeStr = GetEnhancedRegimeString(confluenceRegime.regime);
    color regimeColor = clrWhite;
    
    switch(confluenceRegime.regime) {
        case REGIME_TRENDING_STRONG:
            regimeColor = confluenceRegime.direction > 0 ? clrLimeGreen : clrCrimson;
            break;
        case REGIME_TRENDING_WEAK:
            regimeColor = confluenceRegime.direction > 0 ? clrGreenYellow : clrOrangeRed;
            break;
        case REGIME_RANGING_NARROW:
            regimeColor = clrSkyBlue;
            break;
        case REGIME_RANGING_WIDE:
            regimeColor = clrRoyalBlue;
            break;
        case REGIME_VOLATILE_BREAKOUT:
            regimeColor = clrMagenta;
            break;
        case REGIME_VOLATILE_REVERSAL:
            regimeColor = clrPurple;
            break;
        case REGIME_TRANSITIONAL:
            regimeColor = clrGoldenrod;
            break;
    }
    
    // Create or update regime box background
    if (!ObjectFind(0, regimeBoxName)) {
        ObjectCreate(0, regimeBoxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_XDISTANCE, 220);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_YDISTANCE, 25);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_XSIZE, 210);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_YSIZE, 90);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_BGCOLOR, clrBlack);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_BACK, false);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, regimeBoxName, OBJPROP_HIDDEN, true);
    }
    ObjectSetInteger(0, regimeBoxName, OBJPROP_COLOR, regimeColor);
    
    // Create or update regime label
    if (!ObjectFind(0, regimeLabelName)) {
        ObjectCreate(0, regimeLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, regimeLabelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, regimeLabelName, OBJPROP_XDISTANCE, 215);
        ObjectSetInteger(0, regimeLabelName, OBJPROP_YDISTANCE, 40);
        ObjectSetInteger(0, regimeLabelName, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, regimeLabelName, OBJPROP_SELECTABLE, false);
    }
    
    ObjectSetString(0, regimeLabelName, OBJPROP_TEXT, "IPDA REGIME: " + regimeStr);
    ObjectSetInteger(0, regimeLabelName, OBJPROP_COLOR, regimeColor);
    
    // Direction text
    string directionText = confluenceRegime.direction > 0 ? "BULLISH" : 
                          (confluenceRegime.direction < 0 ? "BEARISH" : "NEUTRAL");
    
    // Create or update direction label
    if (!ObjectFind(0, directionName)) {
        ObjectCreate(0, directionName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, directionName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, directionName, OBJPROP_XDISTANCE, 215);
        ObjectSetInteger(0, directionName, OBJPROP_YDISTANCE, 60);
        ObjectSetInteger(0, directionName, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, directionName, OBJPROP_SELECTABLE, false);
    }
    
    ObjectSetString(0, directionName, OBJPROP_TEXT, "Direction: " + directionText);
    ObjectSetInteger(0, directionName, OBJPROP_COLOR, regimeColor);
    
    // Create or update characteristics label
    string characteristicsText = "Strength: " + DoubleToString(confluenceRegime.characteristics.trendStrength, 2) + 
                               " | Vol: " + DoubleToString(confluenceRegime.characteristics.volatility, 2) +
                               " | Mom: " + DoubleToString(confluenceRegime.characteristics.momentum, 2);
    
    if (!ObjectFind(0, characteristicsName)) {
        ObjectCreate(0, characteristicsName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, characteristicsName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, characteristicsName, OBJPROP_XDISTANCE, 215);
        ObjectSetInteger(0, characteristicsName, OBJPROP_YDISTANCE, 80);
        ObjectSetInteger(0, characteristicsName, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, characteristicsName, OBJPROP_SELECTABLE, false);
    }
    
    ObjectSetString(0, characteristicsName, OBJPROP_TEXT, characteristicsText);
    ObjectSetInteger(0, characteristicsName, OBJPROP_COLOR, clrWhite);
    
    // Create dashboard entries for each timeframe (optional)
    CreateTimeframeDashboardEntry(symbol, g_EnhancedRegimes.Monthly, "MN1", 120);
    CreateTimeframeDashboardEntry(symbol, g_EnhancedRegimes.Weekly, "W1", 140);
    CreateTimeframeDashboardEntry(symbol, g_EnhancedRegimes.Daily, "D1", 160);
    CreateTimeframeDashboardEntry(symbol, g_EnhancedRegimes.H4, "H4", 180);
    CreateTimeframeDashboardEntry(symbol, g_EnhancedRegimes.H1, "H1", 200);
    CreateTimeframeDashboardEntry(symbol, g_EnhancedRegimes.M15, "M15", 220);
}

//+------------------------------------------------------------------+
//| Create dashboard entry for a specific timeframe                   |
//+------------------------------------------------------------------+
void CreateTimeframeDashboardEntry(string symbol, EnhancedRegimeInfo &info, string tfName, int yPos) {
    string objName = "IPDA_TF_" + tfName + "_" + symbol;
    
    // Determine color based on regime and direction
    color regimeColor = clrGray;
    switch(info.regime) {
        case REGIME_TRENDING_STRONG:
            regimeColor = info.direction > 0 ? clrLimeGreen : clrCrimson;
            break;
        case REGIME_TRENDING_WEAK:
            regimeColor = info.direction > 0 ? clrGreenYellow : clrOrangeRed;
            break;
        case REGIME_RANGING_NARROW:
            regimeColor = clrSkyBlue;
            break;
        case REGIME_RANGING_WIDE:
            regimeColor = clrRoyalBlue;
            break;
        case REGIME_VOLATILE_BREAKOUT:
            regimeColor = clrMagenta;
            break;
        case REGIME_VOLATILE_REVERSAL:
            regimeColor = clrPurple;
            break;
        case REGIME_TRANSITIONAL:
            regimeColor = clrGoldenrod;
            break;
    }
    
    // Create regime abbreviation
    string regimeAbbr = "";
    switch(info.regime) {
        case REGIME_TRENDING_STRONG: regimeAbbr = "STR"; break;
        case REGIME_TRENDING_WEAK: regimeAbbr = "WTR"; break;
        case REGIME_RANGING_NARROW: regimeAbbr = "NRG"; break;
        case REGIME_RANGING_WIDE: regimeAbbr = "WRG"; break;
        case REGIME_VOLATILE_BREAKOUT: regimeAbbr = "BRK"; break;
        case REGIME_VOLATILE_REVERSAL: regimeAbbr = "REV"; break;
        case REGIME_TRANSITIONAL: regimeAbbr = "TRN"; break;
    }
    
    // Direction symbol
    string dirSymbol = info.direction > 0 ? "↑" : (info.direction < 0 ? "↓" : "→");
    
    // Create label text
    string labelText = tfName + ": " + regimeAbbr + " " + dirSymbol + " (" + 
                      DoubleToString(info.characteristics.trendStrength, 1) + "/" +
                      DoubleToString(info.characteristics.volatility, 1) + ")";
    
    // Create or update the label
    if (!ObjectFind(0, objName)) {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 215);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yPos);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    }
    
    ObjectSetString(0, objName, OBJPROP_TEXT, labelText);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, regimeColor);
}

//+------------------------------------------------------------------+
//| Clean up visualization elements                                  |
//+------------------------------------------------------------------+
void CleanupEnhancedRegimeVisuals(string symbol) {
    // Clean up main panel objects
    string objNames[] = {
        "IPDA_Enhanced_Regime_" + symbol,
        "IPDA_Enhanced_Regime_Box_" + symbol,
        "IPDA_Direction_" + symbol,
        "IPDA_Characteristics_" + symbol
    };
    
    for (int i = 0; i < ArraySize(objNames); i++) {
        if (ObjectFind(0, objNames[i]) >= 0) {
            ObjectDelete(0, objNames[i]);
        }
    }
    
    // Clean up timeframe dashboard entries
    string timeframes[] = {"MN1", "W1", "D1", "H4", "H1", "M15"};
    
    for (int i = 0; i < ArraySize(timeframes); i++) {
        string tfName = "IPDA_TF_" + timeframes[i] + "_" + symbol;
        if (ObjectFind(0, tfName) >= 0) {
            ObjectDelete(0, tfName);
        }
    }
}

#endif // __IPDA_ENHANCED_REGIME__