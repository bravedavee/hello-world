#ifndef __IPDA_TRADEMANAGEMENT__
#define __IPDA_TRADEMANAGEMENT__

// Proper include order
#include <IPDA_DLLImports.mqh>
#include <IPDA_ExternalFunctions.mqh>
#include <IPDA_Globals.mqh>
#include <IPDA_Logger.mqh>
#include <IPDA_MacroLevels.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/Trade.mqh>

// Input parameters
input double PartialClosePercentage = 50.0;    // Percentage to close on partial exits
input double BreakEvenPips = 15.0;             // Pips needed to move to break-even
input double TrailingStopPips = 25.0;          // Trailing stop distance in pips

//+------------------------------------------------------------------+
//| ManageTrades - Manage all open positions for a symbol            |
//| Parameters:                                                      |
//|   symbol - The trading instrument to manage positions for        |
//|   tradeObj - Reference to a CTrade object for trade operations  |
//+------------------------------------------------------------------+
void ManageTrades(string symbol, CTrade &tradeObj) {
    // Get current price levels
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Create a position info object
    CPositionInfo position;
    
    // Loop through all open positions
    for (int i = 0; i < PositionsTotal(); i++) {
        // Only manage positions for the specified symbol
        if (position.SelectByIndex(i) && position.Symbol() == symbol) {
            // Get position properties
            ulong ticket = position.Ticket();
            double openPrice = position.PriceOpen();
            double stopLoss = position.StopLoss();
            double takeProfit = position.TakeProfit();
            double positionVolume = position.Volume();
            ENUM_POSITION_TYPE positionType = position.PositionType();
            string comment = position.Comment();
            
            // Calculate current profit in pips
            double currentProfitPips = 0;
            if (positionType == POSITION_TYPE_BUY) {
                currentProfitPips = (bid - openPrice) / point / 10;
            } else {
                currentProfitPips = (openPrice - ask) / point / 10;
            }
            
            // Check if this is a swing trade by looking at the comment
            bool isSwingTrade = (StringFind(comment, "SWING") >= 0);
            
            // Get current momentum
            double momentum = 0;
            if (positionType == POSITION_TYPE_BUY) {
                momentum = CalculateMomentum(symbol, PERIOD_H1);
            } else {
                momentum = -CalculateMomentum(symbol, PERIOD_H1);
            }
            
            // Calculate target pips for break-even and trailing
            double breakEvenPips = BreakEvenPips;
            double trailingStopPips = TrailingStopPips;
            
            // For swing trades with positive momentum, allow more room
            if (isSwingTrade && momentum > 0.2) {
                // Increase thresholds by 50% for swing trades with alignment
                breakEvenPips *= 1.5;
                trailingStopPips *= 1.5;
                LogInfo("TRADE_MGMT", "Swing trade with momentum " + DoubleToString(momentum, 2) + 
                       " - using extended management parameters");
            }
            
            // Move to break-even if profit exceeds breakEvenPips
            if (currentProfitPips >= breakEvenPips && stopLoss != openPrice) {
                // Set stop loss to entry price plus 1 pip buffer
                double newStopLoss = openPrice + (positionType == POSITION_TYPE_BUY ? 1 : -1) * 10 * point;
                if (tradeObj.PositionModify(ticket, newStopLoss, takeProfit)) {
                    LogInfo("TRADE_MGMT", "Moved SL to break-even for ticket " + IntegerToString(ticket) + 
                           " at " + DoubleToString(newStopLoss, digits));
                }
            }
            
            // Implement partial close at 50% of target
            double targetPips = MathAbs(takeProfit - openPrice) / point / 10;
            double halfTargetPips = targetPips * 0.5;
            
            // If profit > 50% of target and we haven't partially closed yet
            if (currentProfitPips >= halfTargetPips && positionVolume > CalculateMinLot(symbol)) {
                // Only apply partial close if this isn't a swing trade with aligned momentum
                if (!(isSwingTrade && momentum > 0.2)) {
                    double volumeToClose = positionVolume * (PartialClosePercentage / 100.0);
                    // Ensure we're not closing below minimum lot size
                    volumeToClose = MathMax(volumeToClose, CalculateMinLot(symbol));
                    volumeToClose = MathMin(volumeToClose, positionVolume - CalculateMinLot(symbol));
                    
                    if (volumeToClose > 0) {
                        if (tradeObj.PositionClosePartial(ticket, volumeToClose)) {
                            LogInfo("TRADE_MGMT", "Partially closed " + DoubleToString(volumeToClose, 2) + 
                                   " lots for ticket " + IntegerToString(ticket) + " at " + 
                                   DoubleToString(positionType == POSITION_TYPE_BUY ? bid : ask, digits));
                        }
                    }
                } else {
                    LogInfo("TRADE_MGMT", "Skipping partial close for swing trade with aligned momentum");
                }
            }
            
            // Implement trailing stop
            if (currentProfitPips >= trailingStopPips) {
                double newTrailingStop = 0;
                if (positionType == POSITION_TYPE_BUY) {
                    // Calculate new stop level: current price - trailing distance
                    newTrailingStop = bid - trailingStopPips * 10 * point;
                    // Only move stop if it would move it higher
                    if (newTrailingStop > stopLoss) {
                        if (tradeObj.PositionModify(ticket, newTrailingStop, takeProfit)) {
                            LogInfo("TRADE_MGMT", "Updated trailing stop for ticket " + IntegerToString(ticket) + 
                                   " to " + DoubleToString(newTrailingStop, digits));
                        }
                    }
                } else {
                    // Calculate new stop level: current price + trailing distance
                    newTrailingStop = ask + trailingStopPips * 10 * point;
                    // Only move stop if it would move it lower
                    if (newTrailingStop < stopLoss || stopLoss == 0) {
                        if (tradeObj.PositionModify(ticket, newTrailingStop, takeProfit)) {
                            LogInfo("TRADE_MGMT", "Updated trailing stop for ticket " + IntegerToString(ticket) + 
                                   " to " + DoubleToString(newTrailingStop, digits));
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| IsNearLevel - Check if price is near a key level                 |
//| Parameters:                                                      |
//|   price - The current price to check                             |
//|   level - The key level to compare against                       |
//|   outProximity - Output parameter - how far away in pips         |
//| Returns: true if price is within 10 pips of the level            |
//+------------------------------------------------------------------+
bool IsNearLevel(double price, double level, double &outProximity) {
    // If level is not valid, return false
    if (level == 0)
        return false;
    
    // Calculate proximity in pips
    outProximity = MathAbs(price - level) / _Point;
    
    // Return true if within threshold (10 pips)
    return outProximity < 10.0;
}

//+------------------------------------------------------------------+
//| Calculate minimum lot size for the symbol                         |
//+------------------------------------------------------------------+
double CalculateMinLot(string symbol) {
    return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
}

#endif // __IPDA_TRADEMANAGEMENT__