//+------------------------------------------------------------------+
//| IPDA_Globals.mqh - Shared global definitions                     |
//+------------------------------------------------------------------+
#ifndef __IPDA_GLOBALS__
#define __IPDA_GLOBALS__

// Ensure DLL imports are included at the top for proper recognition
#include "IPDA_DLLImports.mqh"

// Include the centralized timeframe definitions first (using quotes for local files)
#include "IPDA_TimeFrames.mqh"
#include "IPDA_ExternalFunctions.mqh"

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
// Helper function to check string contents
bool ContainsSubstring(const string& text, const string& substring) {
    return StringFind(text, substring) != -1;
}

// Function using Windows API from IPDA_DLLImports.mqh
void ShowMessageBox(string message, string title) {
    int result = MessageBoxW(0, message, title, 0);
    if(result == 0) {
        int error = GetLastError();
        Print("MessageBox error: ", error);
    }
}

//+------------------------------------------------------------------+
//| Enum definitions                                                 |
//+------------------------------------------------------------------+
// Setup quality enum
enum ENUM_IPDA_SETUP_QUALITY {
    QUALITY_POOR = 0,      // Poor quality setup
    QUALITY_MODERATE = 1,  // Moderate quality setup
    QUALITY_GOOD = 2,      // Good quality setup
    QUALITY_EXCELLENT = 3  // Excellent quality setup
};

// Trade setup quality enum
enum ENUM_TRADE_SETUP_QUALITY {
    TRADE_SETUP_WEAK = 0,    // Weak trade setup
    TRADE_SETUP_MEDIUM = 1,  // Medium trade setup
    TRADE_SETUP_STRONG = 2   // Strong trade setup
};

// Setup quality log enum - Added to fix the missing enum error
enum ENUM_IPDA_SETUP_QUALITY_LOG {
    SETUP_WEAK = 0,    // Weak setup
    SETUP_MEDIUM = 1,  // Medium setup
    SETUP_STRONG = 2   // Strong setup
};

// Market Regime Enum
enum ENUM_MARKET_REGIME_TYPE {
    REGIME_RANGE = 0,    
    REGIME_TREND_BULL,    
    REGIME_TREND_BEAR
};

// Direct enum usage without typedef (MQL5 doesn't support typedef)
#define MarketRegimeType ENUM_MARKET_REGIME_TYPE
#define TradeSetupQuality ENUM_TRADE_SETUP_QUALITY

// IPDA zone types
enum ENUM_IPDA_ZONE_TYPE {
    ZONE_RANGE_HIGH,
    ZONE_75_PERCENT,
    ZONE_MIDPOINT,
    ZONE_25_PERCENT,
    ZONE_RANGE_LOW
};

// Breakout types
enum ENUM_IPDA_BREAKOUT_TYPE {
    BREAKOUT_ABOVE_HIGH,
    BREAKOUT_BELOW_LOW,
    ZONE_TEST_HIGH,
    ZONE_TEST_LOW
};

//+------------------------------------------------------------------+
//| Structure definitions                                            |
//+------------------------------------------------------------------+
// Element Zone structure
struct ElementZone {
    double PriceTop;        // Top price of the zone
    double PriceBottom;     // Bottom price of the zone
    string Name;            // Name/label of the zone
    datetime TimeStart;     // Start time of the zone
    datetime TimeEnd;       // End time of the zone
    double MitigationLevel; // Level at which the zone is mitigated
    bool IsInvalidated;     // Has the zone been invalidated
    string symbol;          // Symbol associated with the zone
    double upper;           // Upper price (same as PriceTop)
    double lower;           // Lower price (same as PriceBottom)
    datetime time;          // Time (same as TimeStart)
    string label;           // Label (same as Name)
    int type;               // Type identifier
    color zoneColor;        // Color to use when visualizing
    bool isActive;          // Whether the zone is currently active
    
    // Constructor with default values
    ElementZone() {
        PriceTop = 0.0;
        PriceBottom = 0.0;
        Name = "";
        TimeStart = 0;
        TimeEnd = 0;
        MitigationLevel = 0.0;
        IsInvalidated = false;
        symbol = "";
        upper = 0.0;
        lower = 0.0;
        time = 0;
        label = "";
        type = 0;
        zoneColor = clrNONE;
        isActive = false;
    }
};

// SweepSignal struct
struct SweepSignal {
    bool Valid;
    bool IsBullish;
    datetime Time;
    datetime Timestamp;
    datetime CandleID;
    double Level;
    double Price;
    int Volume;
    double Intensity;
    
    SweepSignal() {
        Valid = false;
        IsBullish = false;
        Time = 0;
        Timestamp = 0;
        CandleID = 0;
        Level = 0.0;
        Price = 0.0;
        Volume = 0;
        Intensity = 0.0;
    }
};

// IPDARange structure
struct IPDARange {
    double High;
    double Range75;
    double Mid;
    double Range25;
    double Low;
    bool HighSwept;
    bool LowSwept;
    bool MidSwept;
};

// RegimeInfo structure
struct RegimeInfo {
    MarketRegimeType regime;
    double strength;
    datetime lastUpdate;
};

// MTFRegimeInfo structure
struct MTFRegimeInfo {
    RegimeInfo Monthly;
    RegimeInfo Weekly;
    RegimeInfo Daily;
    RegimeInfo H4;
    RegimeInfo H1;
};

//+------------------------------------------------------------------+
//| Class definitions                                                |
//+------------------------------------------------------------------+
// The CConfluenceContext class
class CConfluenceContext {
public:
    bool hasOrderBlock;
    bool hasSNRSweep;
    bool hasRJB;
    int direction; // 1 for bullish, -1 for bearish, 0 for neutral
    int totalElements;
    ENUM_TIMEFRAMES timeframe;
    string category;
    
    CConfluenceContext() {
        hasOrderBlock = false;
        hasSNRSweep = false;
        hasRJB = false;
        direction = 0;
        totalElements = 0;
        timeframe = PERIOD_CURRENT;
        category = "";
    }
};

//+------------------------------------------------------------------+
//| Function prototypes and implementations                          |
//+------------------------------------------------------------------+

// Forward declarations for functions implemented in other files
// Note: These are NOT DLL imports, they are regular MQL5 functions
// defined elsewhere in the project

// Function declarations - remove these if they cause compilation errors
// and implement them directly in the appropriate files

// NOTE: SetupQualityToString has been moved to IPDA_Utility.mqh to avoid duplication

// Helper functions to avoid ambiguous calls
double MQAbs(double value) {
    return MathAbs(value);
}

datetime MQTimeCurrent() {
    return TimeCurrent();
}

string MQIntegerToString(int value) {
    return IntegerToString(value);
}

string MQDoubleToString(double value, int digits) {
    return DoubleToString(value, digits);
}

string MQTimeToString(datetime time, int flags) {
    return TimeToString(time, flags);
}

// Get trade setup quality description
string GetTradeSetupQualityDescription(ENUM_TRADE_SETUP_QUALITY quality) {
    switch(quality) {
        case TRADE_SETUP_WEAK:
            return "Weak trade setup";
        case TRADE_SETUP_MEDIUM:
            return "Medium trade setup";
        case TRADE_SETUP_STRONG:
            return "Strong trade setup";
        default:
            return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Global variable declarations                                     |
//+------------------------------------------------------------------+
// Input parameter for LTF setting
input ENUM_LTF_TIMEFRAMES g_DefaultLTF = LTF_M15; // Default LTF timeframe

// External global variable declarations - properly typed and organized by category
// Core flags and configuration
extern bool g_BypassHTFIfPivot;        // Flag to bypass HTF if pivot found
extern int g_MaxOpenTrades;            // Maximum number of open trades allowed
extern int g_MinTradeInterval;         // Minimum interval between trades (seconds)
extern datetime g_LastTradeTime;       // Time of last trade execution
extern double g_RiskPercentage;        // Risk percentage per trade
extern double g_LotSizeOverride;       // Fixed lot size (if > 0)

// IPDA Range values
extern double g_HTFRangeHigh;          // Highest value of range
extern double g_HTFRange75;            // 75% level of range
extern double g_HTFRangeMid;           // Midpoint of range
extern double g_HTFRange25;            // 25% level of range
extern double g_HTFRangeLow;           // Lowest value of range

// Sweep detection data
extern bool g_SweepDetected;           // Flag for sweep detection
extern bool g_SweepDirectionBull;      // Direction of detected sweep
extern datetime g_SweepDetectedTime;   // Time of detected sweep
extern double g_SweepDetectedLevel;    // Price level of detected sweep
extern SweepSignal g_RecentSweep;      // Detailed sweep signal data

// Market regime data
extern MarketRegimeType g_MarketRegime; // Current market regime type

// Complex data structures
extern MTFRegimeInfo g_MTFRegimes;     // Multi-timeframe regime information
extern IPDARange g_IPDARange;          // IPDA range structure

#endif // __IPDA_GLOBALS__
