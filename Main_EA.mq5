//+------------------------------------------------------------------+
//| Main_EA.mq5 - Final Refactored EA                                |
//+------------------------------------------------------------------+
#property strict

// Remove duplicate imports - these are already included in IPDA_DLLImports.mqh
// Keeping only a single include path to IPDA_DLLImports.mqh
#include <IPDA_DLLImports.mqh>

// Include foundation files with correct dependency order
#include <IPDA_TimeFrames.mqh>
#include <IPDA_Globals.mqh>
#include <IPDA_ExternalFunctions.mqh>
#include <IPDA_Logger.mqh>
#include <IPDA_Utility.mqh>

// Include trading modules
#include <IPDA_MacroLevels.mqh>
#include <IPDA_Range.mqh>
#include <IPDA_Regime.mqh>
#include <IPDA_EnhancedRegime.mqh>  // Added enhanced regime system
#include <IPDA_Sweep.mqh>
#include <IPDA_LTF.mqh>
#include <IPDA_Confluence.mqh>
#include <IPDA_Mitigation.mqh>
#include <IPDA_Entry.mqh>
#include <IPDA_TradeManagement.mqh>

// Include standard MQL5 libraries after our custom includes
#include <Trade/Trade.mqh>

// Input parameters with proper MQL5 syntax
input bool iBypassHTFIfPivot = true;    // Bypass HTF if pivot found
input int iMaxOpenTrades = 1;           // Maximum open trades allowed
input int iMinTradeInterval = 300;      // Minimum seconds between trades
input double iRiskPercentage = 1.0;     // Risk percentage per trade
input double iLotSizeOverride = 0.0;    // Fixed lot size (0 = calculate dynamically)
input bool iDisplayM15Indicators = false;  // Display M15 timeframe indicators
input bool iShowOnlyMovingAverages = true; // Show only moving averages (hide gridlines)

// Global trade object
CTrade trade;

// Global variable definitions - actual storage for extern declarations
bool g_BypassHTFIfPivot;
int g_MaxOpenTrades;
int g_MinTradeInterval;
datetime g_LastTradeTime;
double g_HTFRangeHigh;
double g_HTFRange75;
double g_HTFRangeMid;
double g_HTFRange25;
double g_HTFRangeLow;
bool g_SweepDetected;
bool g_SweepDirectionBull;
datetime g_SweepDetectedTime;
double g_SweepDetectedLevel;
MarketRegimeType g_MarketRegime;
double g_RiskPercentage;
double g_LotSizeOverride;

// Enhanced regime is now declared in IPDA_EnhancedRegime.mqh
// No need to redeclare g_EnhancedRegime here

// ✅ Properly initialize complex structs without using initializer lists
SweepSignal g_RecentSweep;  
MTFRegimeInfo g_MTFRegimes;
IPDARange g_IPDARange;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    InitLogger();
    LogInfo("MainEA", "EA Initialized Successfully.");
    g_BypassHTFIfPivot = iBypassHTFIfPivot;
    g_MaxOpenTrades = iMaxOpenTrades;
    g_MinTradeInterval = iMinTradeInterval;
    g_RiskPercentage = iRiskPercentage;
    g_LotSizeOverride = iLotSizeOverride;
    g_LastTradeTime = 0;
    g_HTFRangeHigh = 0.0;
    g_HTFRange75 = 0.0;
    g_HTFRangeMid = 0.0;
    g_HTFRange25 = 0.0;
    g_HTFRangeLow = 0.0;
    g_SweepDetected = false;
    g_SweepDirectionBull = false;
    g_SweepDetectedTime = 0;
    g_SweepDetectedLevel = 0.0;
    g_MarketRegime = REGIME_RANGE;
    
    // Initialize enhanced regime (now using the globally declared one from IPDA_EnhancedRegime.mqh)
    g_EnhancedRegime.regime = REGIME_RANGING_NARROW;
    g_EnhancedRegime.characteristics.trendStrength = 0.0;
    g_EnhancedRegime.characteristics.volatility = 0.0;
    g_EnhancedRegime.characteristics.momentum = 0.0;
    g_EnhancedRegime.characteristics.marketEfficiency = 0.0;
    g_EnhancedRegime.characteristics.volumeTrend = 0.0;
    g_EnhancedRegime.direction = 0;
    g_EnhancedRegime.lastUpdate = 0;

    // ✅ Properly initialize SweepSignal struct fields
    g_RecentSweep.Valid = false;
    g_RecentSweep.IsBullish = false;
    g_RecentSweep.Time = 0;
    g_RecentSweep.Timestamp = 0;
    g_RecentSweep.CandleID = 0;
    g_RecentSweep.Level = 0.0;
    g_RecentSweep.Price = 0.0;
    g_RecentSweep.Volume = 0;
    g_RecentSweep.Intensity = 0.0;
    
    // ✅ Initialize MTFRegimeInfo struct fields
    g_MTFRegimes.Monthly.regime = REGIME_RANGE;
    g_MTFRegimes.Monthly.strength = 0.0;
    g_MTFRegimes.Monthly.lastUpdate = 0;
    
    g_MTFRegimes.Weekly.regime = REGIME_RANGE;
    g_MTFRegimes.Weekly.strength = 0.0;
    g_MTFRegimes.Weekly.lastUpdate = 0;
    
    g_MTFRegimes.Daily.regime = REGIME_RANGE;
    g_MTFRegimes.Daily.strength = 0.0;
    g_MTFRegimes.Daily.lastUpdate = 0;
    
    g_MTFRegimes.H4.regime = REGIME_RANGE;
    g_MTFRegimes.H4.strength = 0.0;
    g_MTFRegimes.H4.lastUpdate = 0;
    
    g_MTFRegimes.H1.regime = REGIME_RANGE;
    g_MTFRegimes.H1.strength = 0.0;
    g_MTFRegimes.H1.lastUpdate = 0;
    
    // ✅ Initialize IPDARange struct fields
    g_IPDARange.High = 0.0;
    g_IPDARange.Range75 = 0.0;
    g_IPDARange.Mid = 0.0;
    g_IPDARange.Range25 = 0.0;
    g_IPDARange.Low = 0.0;
    g_IPDARange.HighSwept = false;
    g_IPDARange.LowSwept = false;
    g_IPDARange.MidSwept = false;

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert de-initialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    CleanIPDAZones(::Symbol());  // Use global namespace
    CleanBreakoutMarkers(::Symbol());  // Use global namespace
    CleanConfluenceMarkers(::Symbol());  // Use global namespace
    
    // Clean up indicator resources to prevent memory leaks
    CleanupRegimeIndicators();
    CleanupEnhancedRegimeIndicators();  // Add cleanup for enhanced regime indicators
    CleanupEnhancedRegimeVisuals(::Symbol());  // Clean up enhanced regime visualization

    LogInfo("MainEA", "EA Deinitialized Successfully.");
    CloseLogger();
}

//+------------------------------------------------------------------+
//| OnTick function - Main entry point for EA execution              |
//+------------------------------------------------------------------+
void OnTick() {
    string symbol = ::Symbol(); // Use global namespace operator

    // Beautify the chart before processing
    BeautifyChart(symbol);

    // Use MQL5 constants directly without qualification
    if (!TimeFrameCheck(symbol, (ENUM_TIMEFRAMES)PERIOD_H4))
        return;

    // Clean visuals
    CleanIPDAZones(symbol);
    CleanBreakoutMarkers(symbol);
    CleanConfluenceMarkers(symbol);

    // Update Macro levels
    UpdateMacroLevels(symbol);

    // Calculate IPDA range - Explicitly cast PERIOD_H4 to ENUM_TIMEFRAMES to avoid ambiguity
    if (!CalculateIPDARange(symbol, (ENUM_TIMEFRAMES)PERIOD_H4)) {
        LogError("MainEA", "Failed to calculate IPDA range for " + symbol);
        return;
    }

    // Only visualize zones if display indicators is enabled
    if (iDisplayM15Indicators) {
        VisualizeIPDAZones(symbol);
    } else if (iShowOnlyMovingAverages) {
        // Draw only moving averages instead of full IPDA zones
        DrawMovingAverages(symbol);
    }
    
    // Create ElementZone variable before passing as reference
    ElementZone obZone;
    
    // Detect order blocks with proper variable initialization
    if (DetectLTFOrderBlock(symbol, (ENUM_LTF_TIMEFRAMES)LTF_M15, true, obZone)) {
        LogInfo("MainEA", "Found bullish order block at " + DoubleToString(obZone.PriceTop, _Digits));
    }
    
    // Explicitly cast PERIOD_H4 to ENUM_TIMEFRAMES to avoid ambiguity
    ScanHTFConfluence(symbol, (ENUM_TIMEFRAMES)PERIOD_H4);

    // Update Market Regime - Now uses our improved regime detection with proper error handling
    // Initialize indicators first to avoid errors
    if (InitializeIndicators(symbol, (ENUM_TIMEFRAMES)PERIOD_H4)) {
        UpdateMarketRegime(symbol, (ENUM_TIMEFRAMES)PERIOD_H4, true);
        
        // Also update multi-timeframe regimes
        UpdateMTFRegimes(symbol);
        
        // Initialize and update enhanced regime indicators
        if (InitializeEnhancedIndicators(symbol, (ENUM_TIMEFRAMES)PERIOD_H4)) {
            // Update Enhanced Regime for current timeframe
            UpdateEnhancedRegimeForTimeframe(symbol, (ENUM_TIMEFRAMES)PERIOD_H4, g_EnhancedRegime);
            
            // Optionally update all timeframes to get a complete picture
            UpdateAllEnhancedRegimes(symbol);
            
            // Visualize regimes on chart only if enabled
            if (iDisplayM15Indicators) {
                VisualizeMarketRegime(symbol);
                VisualizeEnhancedRegime(symbol);
            }
        } else {
            LogError("MainEA", "Failed to initialize enhanced regime indicators");
        }
    } else {
        LogError("MainEA", "Failed to initialize basic regime indicators");
    }
    
    // Replace EnumToString with switch statement
    string regimeStr;
    switch(g_MarketRegime) {
        case REGIME_RANGE: regimeStr = "Range"; break;
        case REGIME_TREND_BULL: regimeStr = "Bullish"; break;
        case REGIME_TREND_BEAR: regimeStr = "Bearish"; break;
        default: regimeStr = "Unknown";
    }
    LogInfo("MainEA", "Market Regime => " + regimeStr);
    
    // Log enhanced regime information
    string enhancedRegimeStr = GetEnhancedRegimeString(g_EnhancedRegime.regime);
    string directionStr = g_EnhancedRegime.direction > 0 ? "Bullish" : (g_EnhancedRegime.direction < 0 ? "Bearish" : "Neutral");
    LogInfo("MainEA", "Enhanced Regime => " + enhancedRegimeStr + " (" + directionStr + 
           ") - Strength: " + DoubleToString(g_EnhancedRegime.characteristics.trendStrength, 2) + 
           ", Vol: " + DoubleToString(g_EnhancedRegime.characteristics.volatility, 2));

    // Detect price sweeps - sweep detection relies on the IPDA range calculation
    DetectPriceSweep(symbol, (ENUM_TIMEFRAMES)PERIOD_H4);

    // Get trade parameters for current regime
    TradeParameters tradeParams;
    AdaptStrategyToRegime(g_EnhancedRegime.regime, g_EnhancedRegime.direction, tradeParams);

    // Check for pivot zone trade setup around daily pivot
    bool pivotZoneEntry = CheckPivotZoneEntry(symbol);
    if (pivotZoneEntry) {
        LogInfo("MainEA", "Pivot zone entry signal detected - Multi-timeframe confirmation");
    }

    // Check for MA crossover near daily pivot
    bool maCrossover = CheckMACrossoverNearPivot(symbol);
    if (maCrossover) {
        LogInfo("MainEA", "MA Crossover detected near daily pivot point");
    }

    // Check entry conditions - now we consider pivot zone entries as valid setups
    if (CheckEntryConditions(symbol, (ENUM_TIMEFRAMES)PERIOD_H4, (ENUM_LTF_TIMEFRAMES)LTF_M15) 
        || maCrossover 
        || pivotZoneEntry) {
        
        LogInfo("MainEA", "Entry Conditions Confirmed. Evaluating trade direction...");

        // Determine trade direction based on current market conditions
        bool canBuy = false;
        bool canSell = false;
        
        // Check pivot zone entry direction first - this has highest priority
        if (pivotZoneEntry) {
            int pivotZoneDirection = GetMAsCrossoverDirection(symbol, PERIOD_M15);
            if (pivotZoneDirection > 0) {
                canBuy = true;
                LogInfo("MainEA", "Pivot zone entry indicates bullish bias");
            } else if (pivotZoneDirection < 0) {
                canSell = true;
                LogInfo("MainEA", "Pivot zone entry indicates bearish bias");
            }
        }
        // For MA crossover strategy (secondary priority)
        else if (maCrossover) {
            // MA Crossover direction takes precedence when it exists
            int crossoverDirection = GetMACrossoverDirection(symbol);
            if (crossoverDirection > 0) {
                canBuy = true;
                LogInfo("MainEA", "MA Crossover indicates bullish bias");
            } else if (crossoverDirection < 0) {
                canSell = true;
                LogInfo("MainEA", "MA Crossover indicates bearish bias");
            }
            
            // Only proceed if crossover direction aligns with overall trend
            if (canBuy && g_EnhancedRegime.direction < 0) {
                LogInfo("MainEA", "MA Crossover direction conflicts with overall trend - not trading");
                canBuy = false;
            } else if (canSell && g_EnhancedRegime.direction > 0) {
                LogInfo("MainEA", "MA Crossover direction conflicts with overall trend - not trading");
                canSell = false;
            }
        }
        // If no specialized entry triggers, use normal direction logic
        else {
            // Use enhanced regime direction
            if (g_EnhancedRegime.direction > 0) {
                canBuy = true;
                LogInfo("MainEA", "Enhanced regime indicates bullish bias");
            } 
            else if (g_EnhancedRegime.direction < 0) {
                canSell = true;
                LogInfo("MainEA", "Enhanced regime indicates bearish bias");
            }
            else {
                // If enhanced regime is neutral, fall back to legacy regime or sweep signals
                LogInfo("MainEA", "Enhanced regime direction is neutral, using legacy signals");
                
                if (g_MarketRegime == REGIME_TREND_BULL) {
                    canBuy = true;
                    LogInfo("MainEA", "Legacy regime indicates bullish bias");
                } 
                else if (g_MarketRegime == REGIME_TREND_BEAR) {
                    canSell = true;
                    LogInfo("MainEA", "Legacy regime indicates bearish bias");
                }
                else if (g_SweepDetected) {
                    // Use sweep signals if available
                    if (g_SweepDirectionBull) {
                        canBuy = true;
                        LogInfo("MainEA", "Sweep indicates bullish bias");
                    } else {
                        canSell = true;
                        LogInfo("MainEA", "Sweep indicates bearish bias");
                    }
                }
            }
        }

        // Apply trading restrictions based on regime-specific parameters
        ENUM_MARKET_REGIME_PRIMARY regime = g_EnhancedRegime.regime;
        
        // Restrict trading based on regime type and trade parameters
        // Pivot zone entries are allowed in ranging markets (special case)
        if (!pivotZoneEntry && (regime == REGIME_RANGING_NARROW || regime == REGIME_RANGING_WIDE) && !tradeParams.allowRangeReversals) {
            LogInfo("MainEA", "Range trading restricted in current regime configuration");
            canBuy = canSell = false;
        }
        
        if (!pivotZoneEntry && (regime == REGIME_VOLATILE_BREAKOUT) && !tradeParams.allowBreakouts) {
            LogInfo("MainEA", "Breakout trading restricted in current regime configuration");
            canBuy = canSell = false;
        }
        
        // Execute trade if conditions are met
        if (canBuy) {
            // If it's a pivot zone entry, use a more conservative trade management approach
            if (pivotZoneEntry) {
                LogInfo("MainEA", "Executing BUY trade based on pivot zone entry");
                ExecutePivotZoneTrade(symbol, ORDER_TYPE_BUY, g_RiskPercentage);
            } else {
                LogInfo("MainEA", "Executing BUY trade in " + enhancedRegimeStr + " regime");
                ExecuteTrade(symbol, ORDER_TYPE_BUY, g_RiskPercentage);
            }
        } 
        else if (canSell) {
            // If it's a pivot zone entry, use a more conservative trade management approach
            if (pivotZoneEntry) {
                LogInfo("MainEA", "Executing SELL trade based on pivot zone entry");
                ExecutePivotZoneTrade(symbol, ORDER_TYPE_SELL, g_RiskPercentage);
            } else {
                LogInfo("MainEA", "Executing SELL trade in " + enhancedRegimeStr + " regime");
                ExecuteTrade(symbol, ORDER_TYPE_SELL, g_RiskPercentage);
            }
        }
        else {
            LogInfo("MainEA", "No clear direction signal or trading is restricted for the current regime");
        }
    }

    // Pass the global trade object to ManageTrades
    ManageTrades(symbol, trade);
}

//+------------------------------------------------------------------+
//| Example of properly handling 'timeframe' - undeclared identifier |
//+------------------------------------------------------------------+
void DemoTimeframeUsage(string symbol) {
    // ✅ Properly declaring the ENUM_TIMEFRAMES variable before using it
    ENUM_TIMEFRAMES timeframe = PERIOD_H1;
    
    double open = ::iOpen(symbol, timeframe, 1);
    double close = ::iClose(symbol, timeframe, 1);
    double high = ::iHigh(symbol, timeframe, 1);
    double low = ::iLow(symbol, timeframe, 1);
    datetime time = ::iTime(symbol, timeframe, 1);
    
    // Use the values...
    LogInfo("DEMO", "Bar Open: " + ::DoubleToString(open, _Digits));
}

//+------------------------------------------------------------------+
//| Example of proper ElementZone initialization & reference handling |
//+------------------------------------------------------------------+
void DemoElementZoneUsage(string symbol, ENUM_TIMEFRAMES timeframe) {
    // ✅ Create and initialize ElementZone before passing as reference
    ElementZone obZone;  // First declare the variable

    // Now we can safely pass it to a function expecting a reference
    if (DetectLTFOrderBlock(symbol, timeframe, true, obZone)) {
        LogInfo("DEMO", "Order block detected at price: " + ::DoubleToString(obZone.PriceTop, _Digits));
        LogInfo("DEMO", "Order block from time: " + ::TimeToString(obZone.TimeStart));
    }
}

//+------------------------------------------------------------------+
//| Example of explicit numeric type conversion to avoid warnings    |
//+------------------------------------------------------------------+
void DemoExplicitCasting(string symbol, ENUM_TIMEFRAMES timeframe) {
    // ✅ Explicit cast for long to double conversion
    long volume = ::iVolume(symbol, timeframe, 0);
    double volumeAsDouble = (double)volume;  // Explicit cast
    
    // ✅ Explicit cast for enum conversion
    ENUM_IPDA_SETUP_QUALITY_LOG logQuality = SETUP_STRONG;
    ENUM_TRADE_SETUP_QUALITY tradeQuality = (ENUM_TRADE_SETUP_QUALITY)logQuality;
    
    // Better approach: use the direct enum value
    tradeQuality = TRADE_SETUP_STRONG;
}

//+------------------------------------------------------------------+
//| Draw only moving averages for less screen clutter                |
//+------------------------------------------------------------------+
void DrawMovingAverages(string symbol) {
    // Draw main moving averages without all other indicators

    // Draw 50 SMA
    string ma50Name = "MA50_" + symbol;
    DrawMovingAverage(symbol, 50, ma50Name, clrRed, STYLE_SOLID, 2);
    
    // Draw 200 SMA
    string ma200Name = "MA200_" + symbol;
    DrawMovingAverage(symbol, 200, ma200Name, clrBlue, STYLE_SOLID, 2);
    
    // Draw 20 EMA - faster MA for crossovers
    string ema20Name = "EMA20_" + symbol;
    DrawMovingAverage(symbol, 20, ema20Name, clrGreen, STYLE_SOLID, 2, MODE_EMA);
}

//+------------------------------------------------------------------+
//| Draw a specific moving average on the chart                      |
//+------------------------------------------------------------------+
void DrawMovingAverage(string symbol, int period, string name, color lineColor, 
                       ENUM_LINE_STYLE style, int width, ENUM_MA_METHOD method = MODE_SMA) {
    
    // Create or update moving average object
    if (!ObjectFind(0, name)) {
        ObjectCreate(0, name, OBJ_TREND, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
    }
    
    // Calculate MA values for current and previous bar
    int maHandle = iMA(symbol, PERIOD_CURRENT, period, 0, method, PRICE_CLOSE);
    double maBuffer[];
    ArraySetAsSeries(maBuffer, true);
    CopyBuffer(maHandle, 0, 0, 2, maBuffer);
    
    double ma1 = maBuffer[0]; // Current bar
    double ma2 = maBuffer[1]; // Previous bar
    
    // Update MA line points
    datetime time1 = iTime(symbol, PERIOD_CURRENT, 0);
    datetime time2 = iTime(symbol, PERIOD_CURRENT, 1);
    
    ObjectMove(0, name, 0, time2, ma2);
    ObjectMove(0, name, 1, time1, ma1);
}

//+------------------------------------------------------------------+
//| Check for MA crossover near a daily pivot point                  |
//+------------------------------------------------------------------+
bool CheckMACrossoverNearPivot(string symbol) {
    // Calculate daily pivot level
    double pivotLevel = CalculateDailyPivot(symbol);
    
    // Get fast and slow MA values
    int fastMAHandle = iMA(symbol, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
    int slowMAHandle = iMA(symbol, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    double fastMA1, fastMA2, slowMA1, slowMA2;
    double fastMABuffer[], slowMABuffer[];
    
    ArraySetAsSeries(fastMABuffer, true);
    ArraySetAsSeries(slowMABuffer, true);
    
    CopyBuffer(fastMAHandle, 0, 1, 2, fastMABuffer);
    CopyBuffer(slowMAHandle, 0, 1, 2, slowMABuffer);
    
    fastMA1 = fastMABuffer[0]; // 1 bar ago
    fastMA2 = fastMABuffer[1]; // 2 bars ago
    
    slowMA1 = slowMABuffer[0]; // 1 bar ago
    slowMA2 = slowMABuffer[1]; // 2 bars ago
    
    // Check for crossover
    bool crossedUp = (fastMA2 < slowMA2) && (fastMA1 > slowMA1);
    bool crossedDown = (fastMA2 > slowMA2) && (fastMA1 < slowMA1);
    bool hasCrossed = crossedUp || crossedDown;
    
    if (!hasCrossed)
        return false;
    
    // Check if crossover is near pivot
    double crossLevel = (fastMA1 + slowMA1) / 2;
    double pipDistance = MathAbs(crossLevel - pivotLevel) / _Point;
    
    // Consider it near if within 50 pips
    bool isNearPivot = (pipDistance < 500);
    
    if (hasCrossed && isNearPivot) {
        LogInfo("PIVOT", "MA Crossover detected near daily pivot: " + 
               (crossedUp ? "BULLISH" : "BEARISH") + 
               " | Distance: " + DoubleToString(pipDistance, 1) + " pips");
        
        // Draw the pivot line
        DrawPivotLine(symbol, pivotLevel, crossedUp ? clrGreen : clrRed);
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get MA crossover direction (1 for bullish, -1 for bearish)       |
//+------------------------------------------------------------------+
int GetMACrossoverDirection(string symbol) {
    int fastMAHandle = iMA(symbol, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
    int slowMAHandle = iMA(symbol, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    double fastMA1, fastMA2, slowMA1, slowMA2;
    double fastMABuffer[], slowMABuffer[];
    
    ArraySetAsSeries(fastMABuffer, true);
    ArraySetAsSeries(slowMABuffer, true);
    
    CopyBuffer(fastMAHandle, 0, 1, 2, fastMABuffer);
    CopyBuffer(slowMAHandle, 0, 1, 2, slowMABuffer);
    
    fastMA1 = fastMABuffer[0]; // 1 bar ago
    fastMA2 = fastMABuffer[1]; // 2 bars ago
    
    slowMA1 = slowMABuffer[0]; // 1 bar ago
    slowMA2 = slowMABuffer[1]; // 2 bars ago
    
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
//| Draw a horizontal pivot line on the chart                        |
//+------------------------------------------------------------------+
void DrawPivotLine(string symbol, double level, color lineColor) {
    string pivotName = "DailyPivot_" + symbol;
    
    // Delete existing pivot line
    ObjectDelete(0, pivotName);
    
    // Create new pivot line
    datetime time1 = iTime(symbol, PERIOD_CURRENT, 20);  // Start 20 bars back
    datetime time2 = iTime(symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 50;  // Extend into future
    
    ObjectCreate(0, pivotName, OBJ_TREND, 0, time1, level, time2, level);
    ObjectSetInteger(0, pivotName, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, pivotName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, pivotName, OBJPROP_WIDTH, 2);
    ObjectSetString(0, pivotName, OBJPROP_TOOLTIP, "Daily Pivot: " + DoubleToString(level, _Digits));
}

// Example of improved MA handle initialization and CopyBuffer usage
int InitializeMAHandle(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price) {
    int handle = iMA(symbol, timeframe, period, 0, method, price);
    if (handle == INVALID_HANDLE) {
        Print("[ERROR] Failed to initialize MA handle for ", symbol, " timeframe: ", timeframe);
    }
    return handle;
}

bool CopyMABuffer(int handle, int bufferIndex, int startPos, int count, double &buffer[]) {
    if (CopyBuffer(handle, bufferIndex, startPos, count, buffer) <= 0) {
        Print("[ERROR] Failed to copy MA buffer. Handle: ", handle, " BufferIndex: ", bufferIndex);
        return false;
    }
    return true;
}

// Example usage in the EA
void UpdateMAData() {
    string symbol = Symbol();
    int fastMAHandle = InitializeMAHandle(symbol, PERIOD_D1, 20, MODE_EMA, PRICE_CLOSE);
    int slowMAHandle = InitializeMAHandle(symbol, PERIOD_D1, 50, MODE_SMA, PRICE_CLOSE);

    if (fastMAHandle != INVALID_HANDLE && slowMAHandle != INVALID_HANDLE) {
        double fastMABuffer[2];
        double slowMABuffer[2];

        if (!CopyMABuffer(fastMAHandle, 0, 0, 2, fastMABuffer) ||
            !CopyMABuffer(slowMAHandle, 0, 0, 2, slowMABuffer)) {
            Print("[ERROR] Failed to update MA data for ", symbol);
        } else {
            Print("[INFO] MA data updated successfully for ", symbol);
        }
    }
}

//+------------------------------------------------------------------+
//| Beautify the chart by removing gridlines and setting colors      |
//+------------------------------------------------------------------+
void BeautifyChart(string symbol) {
    // Remove gridlines
    ChartSetInteger(0, CHART_SHOW_GRID, false);

    // Set elegant candlestick colors
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrGreen); // Bullish candles
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);   // Bearish candles

    // Set background and foreground colors
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);

    // Remove unnecessary objects
    long totalObjects = ObjectsTotal(0, -1, -1);
    for (long i = totalObjects - 1; i >= 0; i--) {
        string objectName = ObjectName(0, i);
        if (StringFind(objectName, "Sweep") != -1 || StringFind(objectName, "Arrow") != -1 || StringFind(objectName, "RSI") != -1 || StringFind(objectName, "ATR") != -1) {
            ObjectDelete(0, objectName);
        }
    }

  
}
