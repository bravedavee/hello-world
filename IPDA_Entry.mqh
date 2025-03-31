//+------------------------------------------------------------------+
//| IPDA_Entry.mqh - Entry logic module with setup quality assessment|
//+------------------------------------------------------------------+
#ifndef __IPDA_ENTRY__
#define __IPDA_ENTRY__

#include "IPDA_DLLImports.mqh"
#include "IPDA_Globals.mqh"  // Include this first to get the ENUM_TRADE_SETUP_QUALITY definition
#include "IPDA_Logger.mqh"
#include "IPDA_Utility.mqh"  // Utility functions including SetupQualityToString
#include <IPDA_Confluence.mqh>
#include <IPDA_LTF.mqh>
#include <IPDA_MacroLevels.mqh>
#include <IPDA_Sweep.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/Trade.mqh>

// External global variables
extern bool g_SweepDetected;
extern bool g_SweepDirectionBull;
extern datetime g_LastTradeTime;
extern int g_MinTradeInterval;
extern int g_MaxOpenTrades;

// Function prototypes
bool CheckEntryConditions(string symbol, ENUM_TIMEFRAMES htfTimeframe, ENUM_LTF_TIMEFRAMES ltfTimeframe);
bool IdentifyLTFConfluence(string symbol, ENUM_LTF_TIMEFRAMES ltfTimeframe);
ENUM_TRADE_SETUP_QUALITY GetTradeSetupQuality(ENUM_TIMEFRAMES timeframe, ENUM_MARKET_REGIME_TYPE regime);
ENUM_TRADE_SETUP_QUALITY GetTradeSetupQualityEnhanced(ENUM_TIMEFRAMES timeframe, ENUM_MARKET_REGIME_PRIMARY enhancedRegime);
void ExecuteTrade(string symbol, ENUM_ORDER_TYPE orderType, double riskPercent);
bool CheckPivotMAEntryConditions(string symbol);
int GetPivotMAEntryDirection(string symbol);
double CalculateDailyPivot(string symbol);
bool CheckPivotZoneEntry(string symbol);
bool CheckMAsCrossover(string symbol, ENUM_TIMEFRAMES timeframe);
int GetMAsCrossoverDirection(string symbol, ENUM_TIMEFRAMES timeframe);
void DrawPivotZone(string symbol, double level, color zoneColor, string description);

//+------------------------------------------------------------------+
//| Check all trade entry conditions                                 |
//+------------------------------------------------------------------+
bool CheckEntryConditions(string symbol, ENUM_TIMEFRAMES htfTimeframe, ENUM_LTF_TIMEFRAMES ltfTimeframe) {
    // Check if enough time has passed since last trade
    if (TimeCurrent() - g_LastTradeTime < g_MinTradeInterval) {
        LogInfo("ENTRY", "Trade interval restriction in effect. Waiting...");
        return false;
    }
    
    // Check if we're already at max trades
    int currentTrades = 0;
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) == symbol) currentTrades++;
    }
    
    if (currentTrades >= g_MaxOpenTrades) {
        LogInfo("ENTRY", "Maximum number of trades (" + IntegerToString(g_MaxOpenTrades) + ") already open");
        return false;
    }
    
    // Check for LTF confluence signals - this is our primary entry trigger
    bool ltfConfluenceDetected = IdentifyLTFConfluence(symbol, ltfTimeframe);
    if (!ltfConfluenceDetected) {
        LogInfo("ENTRY", "No LTF confluence detected, skipping entry check");
        return false;
    }
    
    // Get direction from Enhanced Regime
    int enhancedRegimeDirection = g_EnhancedRegime.direction;
    
    // Check for sweep confirmation - now optional but adds strength
    bool sweepConfirmed = false;
    if (g_SweepDetected && IsSweepValid(3)) {
        sweepConfirmed = ConfirmSweepWithLTF(symbol, ltfTimeframe);
        if (sweepConfirmed) {
            LogInfo("ENTRY", "Sweep confirmed with LTF pattern, adding entry strength");
        }
    }
    
    // Evaluate trade setup quality - Use both legacy and enhanced regimes
    ENUM_TRADE_SETUP_QUALITY legacySetupQuality = GetTradeSetupQuality(htfTimeframe, g_MarketRegime);
    ENUM_TRADE_SETUP_QUALITY enhancedSetupQuality = GetTradeSetupQualityEnhanced(htfTimeframe, g_EnhancedRegime.regime);
    
    // Log both quality assessments for comparison
    LogInfo("ENTRY", "Legacy regime quality: " + SetupQualityToString(legacySetupQuality));
    LogInfo("ENTRY", "Enhanced regime quality: " + SetupQualityToString(enhancedSetupQuality) + 
            " (" + GetEnhancedRegimeString(g_EnhancedRegime.regime) + ")");
    
    // Use the better of the two quality assessments (this allows for a gradual transition to the enhanced regime)
    ENUM_TRADE_SETUP_QUALITY setupQuality = (enhancedSetupQuality > legacySetupQuality) ? 
                                          enhancedSetupQuality : legacySetupQuality;
    
    LogInfo("ENTRY", "Final trade setup quality: " + SetupQualityToString(setupQuality));
    
    // Apply trade parameters based on enhanced regime for risk management
    TradeParameters tradeParams;
    AdaptStrategyToRegime(g_EnhancedRegime.regime, g_EnhancedRegime.direction, tradeParams);
    
    // For debugging only - log the trade parameters
    LogInfo("ENTRY", "Trade parameters adjusted for " + GetEnhancedRegimeString(g_EnhancedRegime.regime) + 
            " - Stop mult: " + DoubleToString(tradeParams.stopMultiplier, 1) + 
            ", Target mult: " + DoubleToString(tradeParams.targetMultiplier, 1));
    
    // MODIFIED DECISION LOGIC: More flexible conditions for trade entry
    // 1. Strong setup quality is always allowed
    // 2. Medium setup with sweep confirmation is allowed
    // 3. Medium setup with momentum aligned to HTF direction is allowed
    
    bool hasStrongSetup = (setupQuality == TRADE_SETUP_STRONG);
    bool hasMediumSetup = (setupQuality == TRADE_SETUP_MEDIUM);
    bool hasSwingPotential = IsSwingPotential(symbol, enhancedRegimeDirection);
    
    // Return true if valid entry conditions are met
    return hasStrongSetup || 
           (hasMediumSetup && (sweepConfirmed || hasSwingPotential));
}

//+------------------------------------------------------------------+
//| Check if momentum aligns with direction for swing potential       |
//+------------------------------------------------------------------+
bool IsSwingPotential(string symbol, int enhancedRegimeDirection) {
    // No swing potential if neutral regime direction
    if (enhancedRegimeDirection == 0) {
        return false;
    }
    
    // Check H4 and Daily timeframes for momentum alignment
    double h4Momentum = CalculateMomentum(symbol, PERIOD_H4);
    double d1Momentum = CalculateMomentum(symbol, PERIOD_D1);
    
    // For bullish regime, we want positive momentum on at least one timeframe
    if (enhancedRegimeDirection > 0) {
        bool h4Aligned = h4Momentum > 0.3;  // Require significant positive momentum
        bool d1Aligned = d1Momentum > 0;    // Any positive momentum on D1 is good
        
        LogInfo("ENTRY", "Swing potential check (Bullish): H4 momentum: " + DoubleToString(h4Momentum, 2) + 
                ", D1 momentum: " + DoubleToString(d1Momentum, 2));
                
        return h4Aligned || d1Aligned;  // Either timeframe showing positive momentum
    }
    // For bearish regime, we want negative momentum on at least one timeframe
    else {
        bool h4Aligned = h4Momentum < -0.3; // Require significant negative momentum
        bool d1Aligned = d1Momentum < 0;    // Any negative momentum on D1 is good
        
        LogInfo("ENTRY", "Swing potential check (Bearish): H4 momentum: " + DoubleToString(h4Momentum, 2) + 
                ", D1 momentum: " + DoubleToString(d1Momentum, 2));
                
        return h4Aligned || d1Aligned;  // Either timeframe showing negative momentum
    }
}

//+------------------------------------------------------------------+
//| Calculate momentum using multiple indicators                      |
//+------------------------------------------------------------------+
double CalculateMomentum(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Get RSI value (14 period)
    int rsiHandle = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
    double rsiBuffer[];
    ArraySetAsSeries(rsiBuffer, true);
    CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer);
    double rsiValue = rsiBuffer[0];
    
    // Normalize RSI from 0-100 to -1 to +1 scale (50 becomes 0)
    double normalizedRsi = (rsiValue - 50.0) / 50.0;
    
    // Get price slope using linear regression
    double prices[];
    int bars = 10; // Look back 10 bars
    ArrayResize(prices, bars);
    
    for(int i = 0; i < bars; i++) {
        prices[i] = iClose(symbol, timeframe, i);
    }
    
    // Calculate slope (simple linear regression approximation)
    double slope = (prices[0] - prices[bars-1]) / bars;
    
    // Normalize slope to approximate -1 to +1 range
    int atrHandle = iATR(symbol, timeframe, 14);
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
    double atr = atrBuffer[0];
    
    double normalizedSlope = 0;
    
    if(atr > 0) {
        normalizedSlope = slope / (atr / 3.0); // Divide by ATR/3 to normalize
        // Clamp value to [-1, 1] range
        normalizedSlope = MathMax(-1.0, MathMin(1.0, normalizedSlope));
    }
    
    // Combine RSI and slope for momentum calculation
    // Weight RSI more on higher timeframes, slope more on lower timeframes
    double rsiWeight = (timeframe >= PERIOD_H4) ? 0.7 : 0.5;
    double slopeWeight = 1.0 - rsiWeight;
    
    double momentum = (normalizedRsi * rsiWeight) + (normalizedSlope * slopeWeight);
    
    return momentum;
}

//+------------------------------------------------------------------+
//| Identify LTF confluence factors                                 |
//+------------------------------------------------------------------+
bool IdentifyLTFConfluence(string symbol, ENUM_LTF_TIMEFRAMES ltfTimeframe) {
    ElementZone zones[4]; // Array to hold different zone types
    bool hasOrderBlock = false;
    bool hasStackedFVG = false;
    bool hasRejectionBlock = false;
    bool hasPivotBreakout = false;
    
    // Check for bullish order blocks
    hasOrderBlock = DetectLTFOrderBlock(symbol, ltfTimeframe, true, zones[0]);
    if (hasOrderBlock) {
        LogInfo("LTF", "Detected bullish order block");
    }
    
    // Check for stacked FVGs
    hasStackedFVG = DetectLTFStackedFVG(symbol, ltfTimeframe, zones[1]);
    if (hasStackedFVG) {
        LogInfo("LTF", "Detected stacked fair value gap");
    }
    
    // Check for rejection blocks
    hasRejectionBlock = DetectLTFRejectionBlock(symbol, ltfTimeframe, zones[2]);
    if (hasRejectionBlock) {
        LogInfo("LTF", "Detected rejection block");
    }
    
    // Check for pivot breakouts
    hasPivotBreakout = DetectPivotBreakout(symbol, ltfTimeframe, zones[3]);
    if (hasPivotBreakout) {
        LogInfo("LTF", "Detected pivot breakout");
    }
    
    // Count how many confluence factors we have
    int confluenceCount = (hasOrderBlock ? 1 : 0) +
                        (hasStackedFVG ? 1 : 0) +
                        (hasRejectionBlock ? 1 : 0) +
                        (hasPivotBreakout ? 1 : 0);
    
    // MODIFIED: We now need only 1 confluence factor for a valid setup
    // This increases the number of potential trade setups
    return (confluenceCount >= 1);
}

//+------------------------------------------------------------------+
//| Determine trade setup quality based on market conditions         |
//+------------------------------------------------------------------+
ENUM_TRADE_SETUP_QUALITY GetTradeSetupQuality(ENUM_TIMEFRAMES timeframe, ENUM_MARKET_REGIME_TYPE regime) {
    // Higher timeframe trending setups are strongest
    if (timeframe >= PERIOD_H4 && (regime == REGIME_TREND_BULL || regime == REGIME_TREND_BEAR))
        return TRADE_SETUP_STRONG;  // Strong setup on H4+ timeframes in confirmed trend
    else if (timeframe >= PERIOD_H1 && (regime == REGIME_TREND_BULL || regime == REGIME_TREND_BEAR))
        return TRADE_SETUP_MEDIUM;  // Medium setup on H1-H4 timeframes in confirmed trend
    else
        return TRADE_SETUP_WEAK;    // Weak setup for lower timeframes or ranging markets
}

//+------------------------------------------------------------------+
//| Determine trade setup quality based on Enhanced Regime           |
//+------------------------------------------------------------------+
ENUM_TRADE_SETUP_QUALITY GetTradeSetupQualityEnhanced(ENUM_TIMEFRAMES timeframe, ENUM_MARKET_REGIME_PRIMARY enhancedRegime) {
    // Evaluate setup quality based on the enhanced regime classification
    switch(enhancedRegime) {
        case REGIME_TRENDING_STRONG:
            return (timeframe >= PERIOD_H4) ? TRADE_SETUP_STRONG : 
                   (timeframe >= PERIOD_H1) ? TRADE_SETUP_MEDIUM : TRADE_SETUP_WEAK;
        
        case REGIME_TRENDING_WEAK:
            return (timeframe >= PERIOD_H4) ? TRADE_SETUP_MEDIUM : TRADE_SETUP_WEAK;
        
        case REGIME_VOLATILE_BREAKOUT:
            return (timeframe >= PERIOD_H1) ? TRADE_SETUP_MEDIUM : TRADE_SETUP_WEAK;
        
        case REGIME_VOLATILE_REVERSAL:
            // Reversals are generally risky, so limit to medium quality at best
            return (timeframe >= PERIOD_H4) ? TRADE_SETUP_MEDIUM : TRADE_SETUP_WEAK;
        
        case REGIME_RANGING_NARROW:
        case REGIME_RANGING_WIDE:
            // Ranging markets typically offer lower quality setups
            return TRADE_SETUP_WEAK;
        
        case REGIME_TRANSITIONAL:
            // Transitional markets are uncertain, so limit to weak quality
            return TRADE_SETUP_WEAK;
        
        default:
            return TRADE_SETUP_WEAK;
    }
}

//+------------------------------------------------------------------+
//| Execute a trade with proper risk management                      |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, ENUM_ORDER_TYPE orderType, double riskPercent) {
    // Get current price
    double entryPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Get trade parameters adapted to current regime
    TradeParameters tradeParams;
    AdaptStrategyToRegime(g_EnhancedRegime.regime, g_EnhancedRegime.direction, tradeParams);
    
    // Calculate stop loss level based on ATR with regime-adapted multiplier
    int atrPeriod = 14;
    double atrValue = iATR(symbol, PERIOD_H1, atrPeriod);
    double stopLossDistance = atrValue * tradeParams.stopMultiplier; // Use regime-specific multiplier
    
    double stopLossLevel = (orderType == ORDER_TYPE_BUY) ? 
                          entryPrice - stopLossDistance : 
                          entryPrice + stopLossDistance;
    
    // NEW: Check for swing potential - if momentum aligns with direction,
    // use more aggressive target multiplier for potential swing trades
    bool hasSwingPotential = IsSwingPotential(symbol, (orderType == ORDER_TYPE_BUY ? 1 : -1));
    
    // Calculate take profit using regime-specific reward:risk ratio
    // For swing potential, increase the target multiplier by 50%
    double targetMultiplier = tradeParams.targetMultiplier;
    if (hasSwingPotential) {
        targetMultiplier *= 1.5; // 50% increase for swing trades
        LogInfo("TRADE", "Swing potential detected - increasing target multiplier to " + 
                DoubleToString(targetMultiplier, 1) + "x");
    }
    
    double takeProfitDistance = stopLossDistance * targetMultiplier;
    double takeProfitLevel = (orderType == ORDER_TYPE_BUY) ? 
                            entryPrice + takeProfitDistance : 
                            entryPrice - takeProfitDistance;
    
    // Calculate lot size based on risk percentage
    double stopLossPoints = MathAbs(entryPrice - stopLossLevel) / _Point;
    double lotSize = CalculateLotSize(symbol, riskPercent, stopLossPoints);
    
    // Create a trade object and execute - renamed to avoid shadowing
    CTrade tradeObj;
    tradeObj.SetDeviationInPoints(10); // Allow 1 pip slippage
    
    // Log the trade details with regime context
    string direction = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
    string regimeStr = GetEnhancedRegimeString(g_EnhancedRegime.regime);
    string tradeType = hasSwingPotential ? "SWING" : "INTRADAY";
    
    LogInfo("TRADE", direction + " " + tradeType + " Entry in " + regimeStr + " regime @ " + 
           DoubleToString(entryPrice, _Digits) + 
           " SL @ " + DoubleToString(stopLossLevel, _Digits) + 
           " TP @ " + DoubleToString(takeProfitLevel, _Digits) + 
           " Lot Size: " + DoubleToString(lotSize, 2));
    
    // Store the trade type in comment field for reference
    string comment = "IPDA_" + tradeType;
    
    // Execute the trade
    bool result = tradeObj.PositionOpen(symbol, orderType, lotSize, entryPrice, 
                                    stopLossLevel, takeProfitLevel, comment);
    
    if (result) {
        g_LastTradeTime = TimeCurrent(); // Update last trade time
        LogInfo("TRADE", "Trade executed successfully. Ticket: " + IntegerToString((int)tradeObj.ResultOrder()));
    } else {
        LogError("TRADE", "Trade execution failed. Error: " + IntegerToString(GetLastError()));
    }
}

//+------------------------------------------------------------------+
//| Execute a trade based on pivot zone entry with specialized risk  |
//+------------------------------------------------------------------+
void ExecutePivotZoneTrade(string symbol, ENUM_ORDER_TYPE orderType, double riskPercent) {
    // Get current price
    double entryPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Calculate daily pivot level - this is our reference point
    double pivotLevel = CalculateDailyPivot(symbol);
    
    // For pivot zone trades, we use a tighter stop loss and smaller targets
    // as they are typically used in ranging markets
    double stopLossDistance = 0.0;
    
    // For BUY trades, stop loss goes below the pivot level
    // For SELL trades, stop loss goes above the pivot level
    if (orderType == ORDER_TYPE_BUY) {
        // For buy trade, SL 10 pips below pivot (or 30 pips from entry if pivot is too far)
        double pivotDistance = (entryPrice - pivotLevel) / _Point;
        if (pivotDistance < 400) { // If pivot is less than 40 pips away
            stopLossDistance = (entryPrice - pivotLevel) + (100 * _Point); // 10 pips below pivot
        } else {
            stopLossDistance = 300 * _Point; // Fixed 30 pips
        }
    } else {
        // For sell trade, SL 10 pips above pivot (or 30 pips from entry if pivot is too far)
        double pivotDistance = (pivotLevel - entryPrice) / _Point;
        if (pivotDistance < 400) { // If pivot is less than 40 pips away
            stopLossDistance = (pivotLevel - entryPrice) + (100 * _Point); // 10 pips above pivot
        } else {
            stopLossDistance = 300 * _Point; // Fixed 30 pips
        }
    }
    
    // Ensure minimum stop loss distance
    stopLossDistance = MathMax(stopLossDistance, 200 * _Point); // Minimum 20 pips
    
    // Calculate stop loss level
    double stopLossLevel = (orderType == ORDER_TYPE_BUY) ? 
                          entryPrice - stopLossDistance : 
                          entryPrice + stopLossDistance;
    
    // For pivot trades, use a smaller target - just 1.5:1 reward to risk
    double takeProfitDistance = stopLossDistance * 1.5;
    double takeProfitLevel = (orderType == ORDER_TYPE_BUY) ? 
                            entryPrice + takeProfitDistance : 
                            entryPrice - takeProfitDistance;
    
    // Calculate lot size based on risk percentage - Pivot trades use lower risk
    double pivotRiskPercent = riskPercent * 0.75; // 25% less risk for pivot trades
    double stopLossPoints = MathAbs(entryPrice - stopLossLevel) / _Point;
    double lotSize = CalculateLotSize(symbol, pivotRiskPercent, stopLossPoints);
    
    // Create trade object - renamed to avoid shadowing
    CTrade tradeObj;
    tradeObj.SetDeviationInPoints(10); // Allow 1 pip slippage
    
    // Log the trade details with pivot reference
    string direction = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
    
    LogInfo("TRADE", direction + " Pivot Zone Entry @ " + DoubleToString(entryPrice, _Digits) + 
           " | Pivot: " + DoubleToString(pivotLevel, _Digits) +
           " | SL @ " + DoubleToString(stopLossLevel, _Digits) + 
           " | TP @ " + DoubleToString(takeProfitLevel, _Digits) + 
           " | Lot Size: " + DoubleToString(lotSize, 2));
    
    // Store the trade type in comment field for reference
    string comment = "IPDA_PivotZone";
    
    // Execute the trade
    bool result = tradeObj.PositionOpen(symbol, orderType, lotSize, entryPrice, 
                                    stopLossLevel, takeProfitLevel, comment);
    
    if (result) {
        g_LastTradeTime = TimeCurrent();
        LogInfo("TRADE", "Pivot Zone trade executed successfully. Ticket: " + IntegerToString((int)tradeObj.ResultOrder()));
    } else {
        LogError("TRADE", "Pivot Zone trade execution failed. Error: " + IntegerToString(GetLastError()));
    }
}

//+------------------------------------------------------------------+
//| Fix explicit enum conversion when needed                         |
//+------------------------------------------------------------------+
void SetupQualityExample() {
    // ✅ Fix for "implicit conversion from 'enum ENUM_IPDA_SETUP_QUALITY_LOG' to 'enum ENUM_TRADE_SETUP_QUALITY'"
    // Instead of implicit conversion:
    // ENUM_TRADE_SETUP_QUALITY quality = SETUP_STRONG;  // Implicit conversion warning
    
    // Use explicit cast:
    ENUM_TRADE_SETUP_QUALITY quality = (ENUM_TRADE_SETUP_QUALITY)SETUP_STRONG;
    
    // Or better, use the correct enum directly:
    quality = TRADE_SETUP_STRONG;  // Direct assignment
    
    // Log with proper conversion 
    LogInfo("ENTRY", "Quality: " + SetupQualityToString(quality));
}

//+------------------------------------------------------------------+
//| Check entry conditions for pivot-based MA crossover strategy      |
//+------------------------------------------------------------------+
bool CheckPivotMAEntryConditions(string symbol) {
    // Check if price is near daily pivot level
    double pivotLevel = CalculateDailyPivot(symbol);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Distance from pivot in pips
    double distanceFromPivot = MathAbs(currentPrice - pivotLevel) / pointSize / 10;
    
    // Check for MA crossover on the daily timeframe
    int ema20Handle = iMA(symbol, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
    int sma50Handle = iMA(symbol, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    double ema20Buffer[], sma50Buffer[];
    ArraySetAsSeries(ema20Buffer, true);
    ArraySetAsSeries(sma50Buffer, true);
    
    CopyBuffer(ema20Handle, 0, 1, 2, ema20Buffer);
    CopyBuffer(sma50Handle, 0, 1, 2, sma50Buffer);
    
    double ema20_1 = ema20Buffer[0];
    double ema20_2 = ema20Buffer[1];
    double sma50_1 = sma50Buffer[0];
    double sma50_2 = sma50Buffer[1];
    
    // Check for a bullish or bearish crossover
    bool bullishCross = (ema20_2 < sma50_2) && (ema20_1 > sma50_1);
    bool bearishCross = (ema20_2 > sma50_2) && (ema20_1 < sma50_1);
    
    // Check overall momentum alignment with H4 timeframe
    double h4Momentum = CalculateMomentum(symbol, PERIOD_H4);
    bool momentumAligned = false;
    
    if (bullishCross && h4Momentum > 0.2) {
        momentumAligned = true;
        LogInfo("PIVOT_ENTRY", "Bullish crossover with positive H4 momentum: " + DoubleToString(h4Momentum, 2));
    }
    else if (bearishCross && h4Momentum < -0.2) {
        momentumAligned = true;
        LogInfo("PIVOT_ENTRY", "Bearish crossover with negative H4 momentum: " + DoubleToString(h4Momentum, 2));
    }
    
    // Entry is valid if:
    // 1. We have a crossover
    // 2. Price is within 50 pips of pivot
    // 3. Momentum aligns with crossover direction
    bool validEntry = (bullishCross || bearishCross) && 
                      (distanceFromPivot < 50) && 
                      momentumAligned;
    
    if (validEntry) {
        LogInfo("PIVOT_ENTRY", "Valid pivot MA crossover entry - Direction: " + 
               (bullishCross ? "BULLISH" : "BEARISH") + 
               " | Distance from pivot: " + DoubleToString(distanceFromPivot, 1) + " pips");
    }
    
    return validEntry;
}

//+------------------------------------------------------------------+
//| Get entry direction for pivot-based MA crossover strategy         |
//+------------------------------------------------------------------+
int GetPivotMAEntryDirection(string symbol) {
    // Check for MA crossover on the daily timeframe
    int ema20Handle = iMA(symbol, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
    int sma50Handle = iMA(symbol, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    double ema20Buffer[], sma50Buffer[];
    ArraySetAsSeries(ema20Buffer, true);
    ArraySetAsSeries(sma50Buffer, true);
    
    CopyBuffer(ema20Handle, 0, 1, 2, ema20Buffer);
    CopyBuffer(sma50Handle, 0, 1, 2, sma50Buffer);
    
    double ema20_1 = ema20Buffer[0];
    double ema20_2 = ema20Buffer[1];
    double sma50_1 = sma50Buffer[0];
    double sma50_2 = sma50Buffer[1];
    
    // Check for a bullish or bearish crossover
    bool bullishCross = (ema20_2 < sma50_2) && (ema20_1 > sma50_1);
    bool bearishCross = (ema20_2 > sma50_2) && (ema20_1 < sma50_1);
    
    if (bullishCross) return 1;  // Bullish direction
    if (bearishCross) return -1; // Bearish direction
    return 0;                   // Neutral or no signal
}

//+------------------------------------------------------------------+
//| Calculate Daily Pivot Point                                      |
//+------------------------------------------------------------------+
double CalculateDailyPivot(string symbol) {
    double prevHigh = iHigh(symbol, PERIOD_D1, 1);
    double prevLow = iLow(symbol, PERIOD_D1, 1);
    double prevClose = iClose(symbol, PERIOD_D1, 1);
    
    // Standard pivot point calculation
    return (prevHigh + prevLow + prevClose) / 3.0;
}

//+------------------------------------------------------------------+
//| Improved Pivot Zone strategy - Multi-timeframe confirmation     |
//+------------------------------------------------------------------+
bool CheckPivotZoneEntry(string symbol) {
    // Calculate daily pivot level
    double pivotLevel = CalculateDailyPivot(symbol);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Get price data for different timeframes
    double h4Close = iClose(symbol, PERIOD_H4, 1);
    double h4Low = iLow(symbol, PERIOD_H4, 1);
    double h1Close = iClose(symbol, PERIOD_H1, 1);
    double h1Open = iOpen(symbol, PERIOD_H1, 1);
    double m15Close = iClose(symbol, PERIOD_M15, 1);
    
    // Check if MA crossover exists on M15
    bool hasCrossover = CheckMAsCrossover(symbol, PERIOD_M15);
    int crossoverDirection = GetMAsCrossoverDirection(symbol, PERIOD_M15);
    
    // Distance from pivot in pips
    double distanceFromPivot = MathAbs(currentPrice - pivotLevel) / pointSize / 10;
    
    LogInfo("PIVOT", "Checking pivot zone entry - Pivot: " + DoubleToString(pivotLevel, _Digits) + 
           ", Current: " + DoubleToString(currentPrice, _Digits) + 
           ", Distance: " + DoubleToString(distanceFromPivot, 1) + " pips");
    
    // Bullish entry criteria:
    // 1. H4 candle went below pivot level (tested/violated pivot)
    // 2. H1 candle closed above pivot after testing it
    // 3. M15 has a bullish MA crossover
    // 4. Current price is near pivot level (within 20 pips)
    bool bullishPivotEntry = 
        (h4Low < pivotLevel) &&              // H4 tested/went below pivot
        (h1Close > pivotLevel) &&            // H1 closed above pivot
        (h1Open < h1Close) &&                // H1 candle is bullish
        (crossoverDirection > 0) &&          // Bullish crossover on M15
        (distanceFromPivot < 20);            // Price is near pivot level
        
    // Bearish entry criteria:
    // 1. H4 candle went above pivot level (tested/violated pivot)
    // 2. H1 candle closed below pivot after testing it
    // 3. M15 has a bearish MA crossover
    // 4. Current price is near pivot level (within 20 pips)
    bool bearishPivotEntry = 
        (h4Low > pivotLevel) &&              // H4 tested/went above pivot
        (h1Close < pivotLevel) &&            // H1 closed below pivot
        (h1Open > h1Close) &&                // H1 candle is bearish
        (crossoverDirection < 0) &&          // Bearish crossover on M15
        (distanceFromPivot < 20);            // Price is near pivot level
    
    // Log entry condition if found
    if (bullishPivotEntry) {
        LogInfo("PIVOT", "Bullish pivot zone entry detected - Multi-timeframe confirmation");
        DrawPivotZone(symbol, pivotLevel, clrLightGreen, "Bullish Pivot Zone Entry");
        return true;
    }
    else if (bearishPivotEntry) {
        LogInfo("PIVOT", "Bearish pivot zone entry detected - Multi-timeframe confirmation");
        DrawPivotZone(symbol, pivotLevel, clrLightPink, "Bearish Pivot Zone Entry");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for MA crossover on specified timeframe                   |
//+------------------------------------------------------------------+
bool CheckMAsCrossover(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Get indicator handles
    int fastMAHandle = iMA(symbol, timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
    int slowMAHandle = iMA(symbol, timeframe, 21, 0, MODE_SMA, PRICE_CLOSE);
    
    // Buffers for the indicator values
    double fastMABuffer[], slowMABuffer[];
    ArraySetAsSeries(fastMABuffer, true);
    ArraySetAsSeries(slowMABuffer, true);
    
    // Copy indicator data
    CopyBuffer(fastMAHandle, 0, 1, 2, fastMABuffer);
    CopyBuffer(slowMAHandle, 0, 1, 2, slowMABuffer);
    
    // Get values from buffers
    double fastMA1 = fastMABuffer[0]; // 1 bar ago
    double fastMA2 = fastMABuffer[1]; // 2 bars ago
    double slowMA1 = slowMABuffer[0]; // 1 bar ago
    double slowMA2 = slowMABuffer[1]; // 2 bars ago
    
    // Check for bullish or bearish crossover
    bool crossedUp = (fastMA2 < slowMA2) && (fastMA1 > slowMA1);
    bool crossedDown = (fastMA2 > slowMA2) && (fastMA1 < slowMA1);
    
    return (crossedUp || crossedDown);
}

//+------------------------------------------------------------------+
//| Get crossover direction on specified timeframe                   |
//+------------------------------------------------------------------+
int GetMAsCrossoverDirection(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Get indicator handles
    int fastMAHandle = iMA(symbol, timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
    int slowMAHandle = iMA(symbol, timeframe, 21, 0, MODE_SMA, PRICE_CLOSE);
    
    // Buffers for the indicator values
    double fastMABuffer[], slowMABuffer[];
    ArraySetAsSeries(fastMABuffer, true);
    ArraySetAsSeries(slowMABuffer, true);
    
    // Copy indicator data
    CopyBuffer(fastMAHandle, 0, 1, 2, fastMABuffer);
    CopyBuffer(slowMAHandle, 0, 1, 2, slowMABuffer);
    
    // Get values from buffers
    double fastMA1 = fastMABuffer[0]; // 1 bar ago
    double fastMA2 = fastMABuffer[1]; // 2 bars ago
    double slowMA1 = slowMABuffer[0]; // 1 bar ago
    double slowMA2 = slowMABuffer[1]; // 2 bars ago
    
    // Bullish crossover
    if ((fastMA2 < slowMA2) && (fastMA1 > slowMA1))
        return 1;
    
    // Bearish crossover
    if ((fastMA2 > slowMA2) && (fastMA1 < slowMA1))
        return -1;
    
    // No crossover
    return 0;
}

//+------------------------------------------------------------------+
//| Draw a pivot zone on the chart                                  |
//+------------------------------------------------------------------+
void DrawPivotZone(string symbol, double level, color zoneColor, string description) {
    string zoneName = "PivotZone_" + symbol;
    string textName = "PivotZoneText_" + symbol;
    
    // Delete existing objects
    ObjectDelete(0, zoneName);
    ObjectDelete(0, textName);
    
    // Calculate zone boundaries (10 pips above and below pivot)
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double upperLevel = level + (10 * 10 * pointSize);
    double lowerLevel = level - (10 * 10 * pointSize);
    
    // Create pivot zone rectangle
    datetime time1 = iTime(symbol, PERIOD_CURRENT, 20);
    datetime time2 = iTime(symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 20;
    
    // Create zone rectangle
    ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, time1, upperLevel, time2, lowerLevel);
    ObjectSetInteger(0, zoneName, OBJPROP_COLOR, zoneColor);
    ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
    ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
    ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
    
    // Create text label
    ObjectCreate(0, textName, OBJ_TEXT, 0, time1, upperLevel + (5 * 10 * pointSize));
    ObjectSetString(0, textName, OBJPROP_TEXT, description);
    ObjectSetInteger(0, textName, OBJPROP_COLOR, zoneColor);
    ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, textName, OBJPROP_FONT, "Arial Bold");
}

#endif // __IPDA_ENTRY__
