//+------------------------------------------------------------------+
//| MQL5_Reference.mqh - Comprehensive Reference with Error Prevention|
//+------------------------------------------------------------------+
#ifndef __MQL5_REFERENCE__
#define __MQL5_REFERENCE__

/*
 * This file contains reference signatures for MQL5 functions
 * specifically addressing common errors in the IPDA EA codebase.
 */

//+------------------------------------------------------------------+
//| Time Series Access Functions - EXACT SIGNATURES                   |
//+------------------------------------------------------------------+

// Correct signatures per MQL5 documentation:
double iOpen(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
double iHigh(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
double iLow(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
double iClose(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
datetime iTime(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
long iVolume(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
long iTickVolume(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
long iRealVolume(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
int iSpread(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);
long iOpenInterest(const string symbol_name, ENUM_TIMEFRAMES timeframe, int shift);

//+------------------------------------------------------------------+
//| Type Definitions and Enumerations for IPDA EA                    |
//+------------------------------------------------------------------+

// Remove duplicate enum definitions and use forward declarations instead
// Simply reference the enums from their original files

// Include the original files that contain the enum definitions
#include <IPDA_TimeFrames.mqh>

// Forward declare struct types - DO NOT REDEFINE THEM
// The actual structs are already defined in IPDA_Globals.mqh
#ifndef __IPDA_GLOBALS__
struct ElementZone;
struct SweepSignal;
#endif

//+------------------------------------------------------------------+
//| Indicator Functions - Common in IPDA EA                          |
//+------------------------------------------------------------------+

int iMA(string symbol, ENUM_TIMEFRAMES timeframe, int ma_period, int ma_shift, 
        ENUM_MA_METHOD ma_method, ENUM_APPLIED_PRICE applied_price);
int iRSI(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_APPLIED_PRICE applied_price);
int iATR(string symbol, ENUM_TIMEFRAMES timeframe, int period);
int iSAR(string symbol, ENUM_TIMEFRAMES timeframe, double step, double maximum);
int iStochastic(string symbol, ENUM_TIMEFRAMES timeframe, int k_period, int d_period, 
               int slowing, ENUM_MA_METHOD ma_method, ENUM_STO_PRICE price_field);

double CopyBuffer(int indicator_handle, int buffer_num, int start_pos, int count, double &buffer[]);
double CopyBuffer(int indicator_handle, int buffer_num, datetime start_time, int count, double &buffer[]);
double CopyClose(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, double &array[]);
double CopyOpen(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, double &array[]);
double CopyHigh(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, double &array[]);
double CopyLow(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, double &array[]);
double CopyTime(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, datetime &array[]);

//+------------------------------------------------------------------+
//| #import Directive Usage - Fix for common import errors            |
//+------------------------------------------------------------------+

/*
 * CORRECT USAGE OF #import:
 * 
 * #import "user32.dll"
 *    int MessageBoxW(int hWnd, string lpText, string lpCaption, int uType);
 * #import
 *
 * The #import directive is ONLY for external DLL functions, NOT for MQH files.
 * For MQH files, always use #include directive:
 * 
 * #include <Trade/Trade.mqh>
 */

//+------------------------------------------------------------------+
//| Order Block Detection - Function references                      |
//+------------------------------------------------------------------+

// LTF Order Block function declaration - DO NOT IMPLEMENT HERE
bool DetectLTFOrderBlock(string symbol, ENUM_LTF_TIMEFRAMES ltfTimeframe, bool isBullish, ElementZone &obZone);
bool DetectLTFOrderBlock(string symbol, ENUM_TIMEFRAMES timeframe, bool isBullish, ElementZone &obZone);

//+------------------------------------------------------------------+
//| Proper Type Casting Examples - For Long to Double conversions    |
//+------------------------------------------------------------------+

/*
 * CORRECT: Use explicit casts for numeric conversions
 * double volume = (double)iVolume(Symbol(), PERIOD_CURRENT, 0);
 *
 * INCORRECT: Implicit conversion (causes warnings)
 * double volume = iVolume(Symbol(), PERIOD_CURRENT, 0);
 */

//+------------------------------------------------------------------+
//| Reference Parameter Usage - For "cannot be initialized" errors   |
//+------------------------------------------------------------------+

/*
 * CORRECT Reference Parameter Usage:
 * 
 * void SomeFunction(int &refParam)
 * {
 *    refParam = 10; // Modify the reference
 * }
 * 
 * // Calling code:
 * int value;
 * SomeFunction(value);
 * 
 * INCORRECT (causes initialization error):
 * SomeFunction(10); // Cannot initialize reference with literal
 */

//+------------------------------------------------------------------+
//| String Functions - Common in IPDA_Sweep.mqh                      |
//+------------------------------------------------------------------+

string DoubleToString(double value, int digits=8);
string IntegerToString(long number, int str_len=0, ushort fill_symbol=' ');
string TimeToString(datetime value, int mode=TIME_DATE|TIME_MINUTES);
int StringLen(string text);
int StringFind(string text, string match, int start_pos=0);

//+------------------------------------------------------------------+
//| Object Creation Functions - Used in visualization                |
//+------------------------------------------------------------------+

bool ObjectCreate(long chart_id, string name, ENUM_OBJECT type, int sub_window,
                  datetime time1, double price1, datetime time2=0, double price2=0);
bool ObjectSetString(long chart_id, string name, ENUM_OBJECT_PROPERTY_STRING prop_id, string text);
bool ObjectSetInteger(long chart_id, string object_name, ENUM_OBJECT_PROPERTY_INTEGER prop_id, long prop_value);
bool ObjectSetDouble(long chart_id, string object_name, ENUM_OBJECT_PROPERTY_DOUBLE prop_id, double prop_value);
bool ObjectDelete(long chart_id, string name);

//+------------------------------------------------------------------+
//| Time and Date Functions                                          |
//+------------------------------------------------------------------+

datetime TimeCurrent();
int TimeYear(const datetime &time);
int TimeMonth(const datetime &time);
int TimeDay(const datetime &time);
int TimeHour(const datetime &time);
int TimeMinute(const datetime &time);
int TimeSeconds(const datetime &time);
int TimeDayOfWeek(const datetime &time);
int TimeDayOfYear(const datetime &time);
int PeriodSeconds(ENUM_TIMEFRAMES period=PERIOD_CURRENT);
datetime TimeTradeServer();

//+------------------------------------------------------------------+
//| Common Error Fixes for IPDA EA                                   |
//+------------------------------------------------------------------+

// Fix for "reference cannot be initialized" errors
// Use a variable for reference parameters:
/*
ElementZone zone;
bool result = DetectLTFOrderBlock(Symbol(), PERIOD_CURRENT, true, zone);
*/

// Fix for "undeclared identifier" errors with timeframe
// Always use proper ENUM_TIMEFRAMES values:
/*
ENUM_TIMEFRAMES tf = PERIOD_H1; 
double high = iHigh(Symbol(), tf, 1);
*/

// Fix for enum conversion warnings
// Use explicit casting or correct enum type:
/*
// Explicit cast
ENUM_TRADE_SETUP_QUALITY quality = (ENUM_TRADE_SETUP_QUALITY)SETUP_STRONG;

// Correct enum usage
ENUM_TRADE_SETUP_QUALITY quality = TRADE_SETUP_STRONG;
*/

// Fix for "no #import declaration" errors
// Only use #import for DLLs, use #include for .mqh files:
/*
// CORRECT
#include <IPDA_Globals.mqh>

// CORRECT - For external DLLs only
#import "user32.dll"
   int MessageBoxW(int hWnd, string lpText, string lpCaption, int uType);
#import
*/

//+------------------------------------------------------------------+
//| Special Character Handling - Ampersand Usage Reference           |
//+------------------------------------------------------------------+

/*
 * AMPERSAND CHARACTER USAGE IN MQL5:
 *
 * 1. REFERENCE PARAMETERS - Pass by reference
 * 
 * CORRECT:
 * void Function(int &parameter) {
 *    parameter = 10; // Modifies the original variable
 * }
 * 
 * USAGE:
 * int value = 5;
 * Function(value); // value becomes 10 after the call
 *
 * 2. TOOLTIP TEXT - Ampersand requires doubling
 *
 * INCORRECT:
 * ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Price & Volume");
 * // Displays as "Price  Volume" (ampersand disappears)
 *
 * CORRECT:
 * ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Price && Volume");
 * // Displays as "Price & Volume"
 *
 * 3. OBJECT TEXT - Same escaping requirement
 *
 * INCORRECT:
 * ObjectSetString(0, objName, OBJPROP_TEXT, "Buy & Sell Signals");
 * // May not display correctly in some contexts
 *
 * CORRECT:
 * ObjectSetString(0, objName, OBJPROP_TEXT, "Buy && Sell Signals");
 * // Displays correctly in all contexts
 */

//+------------------------------------------------------------------+
//| Ampersand Reference Function Examples                            |
//+------------------------------------------------------------------+

// Reference parameter examples
void ModifyByRef(double &valueToModify) {
   valueToModify *= 2; // Doubles the value
}

// Function to properly escape ampersands
string EscapeAmpersands(string text) {
   string result = text;
   int pos = 0;
   while((pos = StringFind(result, "&", pos)) >= 0) {
      result = StringSubstr(result, 0, pos) + "&&" + 
              StringSubstr(result, pos + 1);
      pos += 2;
   }
   return result;
}

// Function to set tooltip with correct escaping
bool SetTooltipWithAmpersands(long chartId, string objectName, string tooltipText) {
   return ObjectSetString(chartId, objectName, OBJPROP_TOOLTIP, 
                         EscapeAmpersands(tooltipText));
}

#endif // __MQL5_REFERENCE__