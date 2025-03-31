//+------------------------------------------------------------------+
//| IPDA_MacroLevels.mqh - Macro price level detection                |
//+------------------------------------------------------------------+
#ifndef __IPDA_MACROLEVELS__
#define __IPDA_MACROLEVELS__

#include "IPDA_ExternalFunctions.mqh"
#include "IPDA_Globals.mqh"
#include "IPDA_Logger.mqh"
#include "IPDA_TimeFrames.mqh"

// Maximum number of macro levels to track
#define MAX_MACRO_LEVELS 20

// Structure to store macro level data
struct MacroLevel {
    double price;          // Price level
    datetime time;         // Time when level was identified
    int strength;          // Level strength (1-10)
    int hits;              // Number of times price has interacted with level
    string description;    // Description of the level
    color levelColor;      // Color for visualization
    bool isActive;         // Whether the level is still active
};

// Array of macro levels
MacroLevel g_MacroLevels[];

//+------------------------------------------------------------------+
//| Initialize and detect macro levels                               |
//+------------------------------------------------------------------+
void UpdateMacroLevels(string symbol) {
    // First initialization
    if(ArraySize(g_MacroLevels) == 0) {
        ArrayResize(g_MacroLevels, MAX_MACRO_LEVELS);
        InitializeMacroLevels(symbol);
    }
    
    // Update existing levels and check for hits
    UpdateMacroLevelHits(symbol);
    
    // Clean up old or invalidated levels
    CleanupInactiveLevels();
    
    // Detect new levels if needed
    if(TimeFrameCheck(symbol, PERIOD_D1)) {
        DetectNewMacroLevels(symbol);
    }
    
    // Visualize levels
    VisualizeMacroLevels(symbol);
}

//+------------------------------------------------------------------+
//| Initialize macro levels with common key levels                   |
//+------------------------------------------------------------------+
void InitializeMacroLevels(string symbol) {
    // Get daily pivots
    CalculateDailyPivots(symbol, g_MacroLevels[0].price, g_MacroLevels[1].price, 
                         g_MacroLevels[2].price, g_MacroLevels[3].price, 
                         g_MacroLevels[4].price);
    
    // Set up data for pivot levels
    g_MacroLevels[0].time = TimeCurrent();
    g_MacroLevels[0].strength = 8;
    g_MacroLevels[0].hits = 0;
    g_MacroLevels[0].description = "Daily Pivot Point";
    g_MacroLevels[0].levelColor = clrOrange;
    g_MacroLevels[0].isActive = true;
    
    // Resistance 1
    g_MacroLevels[1].time = TimeCurrent();
    g_MacroLevels[1].strength = 7;
    g_MacroLevels[1].hits = 0;
    g_MacroLevels[1].description = "R1";
    g_MacroLevels[1].levelColor = clrCrimson;
    g_MacroLevels[1].isActive = true;
    
    // Support 1
    g_MacroLevels[2].time = TimeCurrent();
    g_MacroLevels[2].strength = 7;
    g_MacroLevels[2].hits = 0;
    g_MacroLevels[2].description = "S1";
    g_MacroLevels[2].levelColor = clrDodgerBlue;
    g_MacroLevels[2].isActive = true;
    
    // Resistance 2
    g_MacroLevels[3].time = TimeCurrent();
    g_MacroLevels[3].strength = 6;
    g_MacroLevels[3].hits = 0;
    g_MacroLevels[3].description = "R2";
    g_MacroLevels[3].levelColor = clrIndianRed;
    g_MacroLevels[3].isActive = true;
    
    // Support 2
    g_MacroLevels[4].time = TimeCurrent();
    g_MacroLevels[4].strength = 6;
    g_MacroLevels[4].hits = 0;
    g_MacroLevels[4].description = "S2";
    g_MacroLevels[4].levelColor = clrRoyalBlue;
    g_MacroLevels[4].isActive = true;
    
    // Get weekly open
    datetime time = iTime(symbol, PERIOD_W1, 0);
    g_MacroLevels[5].price = iOpen(symbol, PERIOD_W1, 0);
    g_MacroLevels[5].time = time;
    g_MacroLevels[5].strength = 8;
    g_MacroLevels[5].hits = 0;
    g_MacroLevels[5].description = "Weekly Open";
    g_MacroLevels[5].levelColor = clrGold;
    g_MacroLevels[5].isActive = true;
    
    // Get daily open
    time = iTime(symbol, PERIOD_D1, 0);
    g_MacroLevels[6].price = iOpen(symbol, PERIOD_D1, 0);
    g_MacroLevels[6].time = time;
    g_MacroLevels[6].strength = 7;
    g_MacroLevels[6].hits = 0;
    g_MacroLevels[6].description = "Daily Open";
    g_MacroLevels[6].levelColor = clrDarkOrange;
    g_MacroLevels[6].isActive = true;
    
    // Get monthly open
    time = iTime(symbol, PERIOD_MN1, 0);
    g_MacroLevels[7].price = iOpen(symbol, PERIOD_MN1, 0);
    g_MacroLevels[7].time = time;
    g_MacroLevels[7].strength = 9;
    g_MacroLevels[7].hits = 0;
    g_MacroLevels[7].description = "Monthly Open";
    g_MacroLevels[7].levelColor = clrMagenta;
    g_MacroLevels[7].isActive = true;
    
    // Previous day high/low
    g_MacroLevels[8].price = iHigh(symbol, PERIOD_D1, 1);
    g_MacroLevels[8].time = iTime(symbol, PERIOD_D1, 1);
    g_MacroLevels[8].strength = 6;
    g_MacroLevels[8].hits = 0;
    g_MacroLevels[8].description = "Prev Day High";
    g_MacroLevels[8].levelColor = clrCrimson;
    g_MacroLevels[8].isActive = true;
    
    g_MacroLevels[9].price = iLow(symbol, PERIOD_D1, 1);
    g_MacroLevels[9].time = iTime(symbol, PERIOD_D1, 1);
    g_MacroLevels[9].strength = 6;
    g_MacroLevels[9].hits = 0;
    g_MacroLevels[9].description = "Prev Day Low";
    g_MacroLevels[9].levelColor = clrDodgerBlue;
    g_MacroLevels[9].isActive = true;
}

//+------------------------------------------------------------------+
//| Calculate daily pivot points                                     |
//+------------------------------------------------------------------+
void CalculateDailyPivots(string symbol, double &pivot, double &r1, double &s1, double &r2, double &s2) {
    // Get yesterday's high, low, and close
    double prevHigh = iHigh(symbol, PERIOD_D1, 1);
    double prevLow = iLow(symbol, PERIOD_D1, 1);
    double prevClose = iClose(symbol, PERIOD_D1, 1);
    
    // Calculate pivot
    pivot = (prevHigh + prevLow + prevClose) / 3.0;
    
    // Calculate support and resistance levels
    r1 = (2.0 * pivot) - prevLow;
    s1 = (2.0 * pivot) - prevHigh;
    r2 = pivot + (prevHigh - prevLow);
    s2 = pivot - (prevHigh - prevLow);
}

//+------------------------------------------------------------------+
//| Update hit counts for existing macro levels                      |
//+------------------------------------------------------------------+
void UpdateMacroLevelHits(string symbol) {
    // Get current price
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Get price range for the last few candles
    double high = iHigh(symbol, PERIOD_H1, 0);
    double low = iLow(symbol, PERIOD_H1, 0);
    
    // Define proximity tolerance (0.1% of current price)
    double tolerance = currentPrice * 0.001;
    
    // Check each level for hits
    for(int i = 0; i < ArraySize(g_MacroLevels); i++) {
        if(!g_MacroLevels[i].isActive) continue;
        
        // Check if price is near the level
        if(MathAbs(currentPrice - g_MacroLevels[i].price) < tolerance) {
            // Check if high and low span the level (crossed it)
            if(high >= g_MacroLevels[i].price && low <= g_MacroLevels[i].price) {
                g_MacroLevels[i].hits++;
                
                LogInfo("MACRO", "Hit detected on level " + g_MacroLevels[i].description + 
                        " at " + DoubleToString(g_MacroLevels[i].price, _Digits) + 
                        " (hits: " + IntegerToString(g_MacroLevels[i].hits) + ")");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Clean up inactive or old macro levels                            |
//+------------------------------------------------------------------+
void CleanupInactiveLevels() {
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Check each level
    for(int i = 0; i < ArraySize(g_MacroLevels); i++) {
        if(!g_MacroLevels[i].isActive) continue;
        
        // Deactivate levels that are more than a week old and have low hit counts
        if(g_MacroLevels[i].hits < 2 && 
           (currentTime - g_MacroLevels[i].time) > 7 * 24 * 60 * 60) {
            g_MacroLevels[i].isActive = false;
            LogInfo("MACRO", "Deactivated old level " + g_MacroLevels[i].description + 
                   " at " + DoubleToString(g_MacroLevels[i].price, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Detect new macro levels                                          |
//+------------------------------------------------------------------+
void DetectNewMacroLevels(string symbol) {
    // Find index for new levels
    int newIndex = -1;
    for(int i = 0; i < ArraySize(g_MacroLevels); i++) {
        if(!g_MacroLevels[i].isActive) {
            newIndex = i;
            break;
        }
    }
    
    // If no space for new levels, exit
    if(newIndex == -1) return;
    
    // Try to detect new swing high/low levels (simple algorithm)
    double high[], low[];
    if(CopyHigh(symbol, PERIOD_D1, 0, 10, high) < 10 ||
       CopyLow(symbol, PERIOD_D1, 0, 10, low) < 10) {
        LogError("MACRO", "Failed to copy price data for macro level detection");
        return;
    }
    
    // Find potential swing high
    int highIndex = ArrayMaximum(high, 1, 5); // Skip current day
    bool isSwingHigh = true;
    
    // Check if it's a valid swing high
    for(int i = 1; i <= 5; i++) {
        if(i != highIndex && high[i] >= high[highIndex]) {
            isSwingHigh = false;
            break;
        }
    }
    
    // Add swing high as a new level
    if(isSwingHigh) {
        g_MacroLevels[newIndex].price = high[highIndex];
        g_MacroLevels[newIndex].time = TimeCurrent();
        g_MacroLevels[newIndex].strength = 7;
        g_MacroLevels[newIndex].hits = 0;
        g_MacroLevels[newIndex].description = "Swing High";
        g_MacroLevels[newIndex].levelColor = clrFireBrick;
        g_MacroLevels[newIndex].isActive = true;
        
        LogInfo("MACRO", "Added new swing high level at " + 
                DoubleToString(g_MacroLevels[newIndex].price, _Digits));
        
        // Find next available index
        newIndex = -1;
        for(int i = 0; i < ArraySize(g_MacroLevels); i++) {
            if(!g_MacroLevels[i].isActive) {
                newIndex = i;
                break;
            }
        }
        
        // If no more space, exit
        if(newIndex == -1) return;
    }
    
    // Find potential swing low
    int lowIndex = ArrayMinimum(low, 1, 5); // Skip current day
    bool isSwingLow = true;
    
    // Check if it's a valid swing low
    for(int i = 1; i <= 5; i++) {
        if(i != lowIndex && low[i] <= low[lowIndex]) {
            isSwingLow = false;
            break;
        }
    }
    
    // Add swing low as a new level
    if(isSwingLow) {
        g_MacroLevels[newIndex].price = low[lowIndex];
        g_MacroLevels[newIndex].time = TimeCurrent();
        g_MacroLevels[newIndex].strength = 7;
        g_MacroLevels[newIndex].hits = 0;
        g_MacroLevels[newIndex].description = "Swing Low";
        g_MacroLevels[newIndex].levelColor = clrRoyalBlue;
        g_MacroLevels[newIndex].isActive = true;
        
        LogInfo("MACRO", "Added new swing low level at " + 
                DoubleToString(g_MacroLevels[newIndex].price, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Visualize macro levels on chart                                  |
//+------------------------------------------------------------------+
void VisualizeMacroLevels(string symbol) {
    // Clean up old level objects first
    for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string name = ObjectName(0, i);
        if(StringFind(name, "MacroLevel_") >= 0) {
            ObjectDelete(0, name);
        }
    }
    
    // Draw each active level
    for(int i = 0; i < ArraySize(g_MacroLevels); i++) {
        if(!g_MacroLevels[i].isActive) continue;
        
        // Create level line
        string levelName = "MacroLevel_" + IntegerToString(i) + "_" + symbol;
        ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, g_MacroLevels[i].price);
        ObjectSetInteger(0, levelName, OBJPROP_COLOR, g_MacroLevels[i].levelColor);
        ObjectSetInteger(0, levelName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, levelName, OBJPROP_WIDTH, 1);
        
        // Create level label
        string labelName = "MacroLabel_" + IntegerToString(i) + "_" + symbol;
        ObjectCreate(0, labelName, OBJ_TEXT, 0, iTime(symbol, PERIOD_H4, 30), g_MacroLevels[i].price);
        ObjectSetString(0, labelName, OBJPROP_TEXT, g_MacroLevels[i].description + " (" + 
                       IntegerToString(g_MacroLevels[i].hits) + ")");
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, g_MacroLevels[i].levelColor);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    }
}

//+------------------------------------------------------------------+
//| Check if price is near a macro level                             |
//+------------------------------------------------------------------+
bool IsPriceNearMacroLevel(string symbol, double &nearestLevel, double &distance) {
    // Get current price
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Define proximity as 0.2% of current price
    double proximityThreshold = currentPrice * 0.002;
    
    // Initialize variables
    nearestLevel = 0.0;
    distance = DBL_MAX;
    
    // Check each active level
    for(int i = 0; i < ArraySize(g_MacroLevels); i++) {
        if(!g_MacroLevels[i].isActive) continue;
        
        // Calculate distance to this level
        double levelDistance = MathAbs(currentPrice - g_MacroLevels[i].price);
        
        // Update nearest level if this one is closer
        if(levelDistance < distance) {
            distance = levelDistance;
            nearestLevel = g_MacroLevels[i].price;
        }
    }
    
    // Return true if nearest level is within threshold
    return (distance <= proximityThreshold);
}

//+------------------------------------------------------------------+
//| Get the probability of reversal at a macro level                 |
//+------------------------------------------------------------------+
double GetMacroReversalProbability(string symbol, double level) {
    // Find the level in our array
    int levelIndex = -1;
    for(int i = 0; i < ArraySize(g_MacroLevels); i++) {
        if(g_MacroLevels[i].isActive && MathAbs(g_MacroLevels[i].price - level) < 0.0001) {
            levelIndex = i;
            break;
        }
    }
    
    // If level not found, return low probability
    if(levelIndex == -1) return 0.3;
    
    // Calculate probability based on level strength and hit count
    double strengthFactor = g_MacroLevels[levelIndex].strength / 10.0;
    double hitsFactor = MathMin(1.0, g_MacroLevels[levelIndex].hits / 5.0);
    
    // Combine factors (weightings can be adjusted)
    double probability = 0.5 * strengthFactor + 0.5 * hitsFactor;
    
    return MathMin(1.0, probability);
}

#endif // __IPDA_MACROLEVELS__
