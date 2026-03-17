//#property copyright "mitsuaki-41"
#property description "EA using multi-timeframe RSI."
#property description "---- Set Up ----"
#property description "Trend Following = true:"
#property description "Higher RSI Signal Bullish and Current RSI Oversold -> Buy, Higher RSI Signal Bearish and Current RSI Overbought -> Sell."
#property description "Trend Following = false:"
#property description "Higher RSI Signal Bullish and Current RSI Overbought -> Sell, Higher RSI Signal Bearish and Current RSI Oversold -> Buy."
#property description "---- Lot Calculation ----"
#property description "Lot = Equity * Coefficient Value / 1000"
#property description "The Maximum Initial Lot Size is Calculated based on the Lot Multiplier, Loss Count, Division Value."

enum Trend1
{
   Bullish = 1,
   Bearish = -1,
   Range = 0
};
enum Trend2
{
   Fixed_Bullish = 1,
   Fixed_Bearish = -1,
   Disable = 0
};

#include <Trade\Trade.mqh>

input ulong  MagicNumber                   = 123456;    // Magic Number
input group "---- Set Up ----"
input bool   TrendFollowing                = true;      // Trend Following
input Trend1 InitialTrend                  = 0;         // Initial Trend Signal
input Trend2 FixTrend                      = 0;         // Fix Trend Signal
input ENUM_TIMEFRAMES higher_rsi_timeframe = PERIOD_D1; // Higher RSI Timeframe
input int    higher_rsi_period             = 5;         // Higher RSI Period
input double HigherRSIBuying               = 75;        // Bullish Signal Threshold by Higher RSI
input double HigherRSISelling              = 25;        // Bearish Signal Threshold by Higher RSI
input bool   InitializeSignal              = false;     // Off Higher RSI Signal at Range Area
input int    RsiPeriod                     = 9;         // Current RSI Period
input double RsiOverbought                 = 75.0;      // Current RSI Overbought Threshold
input double RsiOversold                   = 25.0;      // Current RSI Oversold Threshold
input bool   DontOpenAfter_SLTP            = true;      // Don't Open After SL/TP until Next Bar
input group "---- Lot ----"
input double LotCoefficient                = 0.0004;    // Lot Coefficient Value (Based on Equity)
input int    MaxLossCount                  = 1;         // Max Count Loss (0: Disable Lot Multiplier)
input double LotMultiplier                 = 2.5;       // Lot Multiplier after Loss Trading
input int    MaxLotDivision                = 1;         // Division Max First Lot
input group "---- Grid ----"
input bool   GridSwitch                    = false;     // Enable Grid
input double GridDistance                  = 0.2;       // Grid Distance Percentage
input double GridMultiplier                = 1.618;     // Multiplier Each Grid Distance
input double GridLotMultiplier             = 1.618;     // Grid Order Lot Multiplier (0: Off)
input group "---- Close ----"
input double TakeProfitPercentage          = 0;         // Take Profit Percentage (0: Off)
input double StopLossPercentage            = 0;         // Stop Loss Percentage (0: Off)
input double LossToRangeFactor             = 1.0;       // Loss to SL/TP Range Factor (1.0: Off)
input bool   CloseWithRSI                  = true;      // Close with Current RSI
input double RsiCloseBought                = 50.0;      // Current RSI Close Bought Threshold
input double RsiCloseSold                  = 50.0;      // Current RSI Close Sold Threshold
input group "---- Debug ----"
input bool   DebugMode                     = false;     // Debug Mode
input double StopEA_MarginLevel            = 25;        // Debug Mode EA Stop Margin Level Percentage
input bool   CommentSwitch                 = true;      // Comment On / Off

CTrade trade;

datetime lastFrameBarTime = 0;
double currentMultiplier = 1.00;
double currentLot = 0.00;
double ShowOptimizedLot = 0.00;
int rsi_handle = INVALID_HANDLE;
int higher_rsi_handle = INVALID_HANDLE;
double higher_rsi = 50.0;
double rsi = 50.0;
double lastProfit = 0.0;
int TrendSignal = 0;
//bool TrendFollowing = true;
double minMarginLevel = 999999;
int LossCount = 0;
double DynamicMultiplier = 0;
string TFstr_current = "";
string TFstr_high = "";
string TrendText = "";
int last_pos_type = -1;
double GridBuyPoint = 0;
double GridSellPoint = 0;
int GridCount = 0;
bool OrderedFlag = false; // ordered flag
datetime pauseUntilTime = 0;
ulong LastCheckedDeal = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    ShowOptimizedLot = GetDynamicLot(LotCoefficient);
    higher_rsi_handle = iRSI(_Symbol, higher_rsi_timeframe, higher_rsi_period, PRICE_CLOSE);
    TrendSignal = InitialTrend;
    rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RsiPeriod, PRICE_CLOSE);
    TFstr_current = TimeframeToString(Period());
    TFstr_high = TimeframeToString(higher_rsi_timeframe);
    if (CommentSwitch == true) Comment("RSI[", TFstr_high, "]: ", DoubleToString(higher_rsi, 2),
                                       "\nRSI[", TFstr_current, "]: ", DoubleToString(rsi, 2),
                                       "\nInitial Lot: ", ShowOptimizedLot);
    if (rsi_handle == INVALID_HANDLE)
    {
        Print("RSI handle creation failed");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if (rsi_handle != INVALID_HANDLE)
        IndicatorRelease(rsi_handle);
    Comment("");
    if (DebugMode == true) Print("✔ Minimum Magin Level: ", DoubleToString(minMarginLevel, 2), "%");
}

//+------------------------------------------------------------------+
void OnTick()
{
    int higher_rsi_signal = GetHigherRsiSignal();
    int rsi_signal = GetRsiSignal();
    int close_signal = GetCloseRsiSignal();
    if (DebugMode == true && PositionsTotal() > 0) CheckForStopByMarginLevel();
    if (PositionsTotal() > 0 && GridSwitch == true)
    {
        if (last_pos_type == POSITION_TYPE_BUY)
        {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(GridBuyPoint > ask)
            {
               GridCount += 1;
               OrderBuy();
            }
        }
        if (last_pos_type == POSITION_TYPE_SELL)
        {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(GridSellPoint < bid) 
            {
               GridCount += 1;
               OrderSell();
            }
        }
    }
    //double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    //double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    //UpdateLastProfit(MagicNumber);
    if      (higher_rsi_signal == -1) TrendSignal = -1;
    else if (higher_rsi_signal ==  1) TrendSignal = 1;
    else if (higher_rsi_signal ==  0 && InitializeSignal == true) TrendSignal = 0;
    if (FixTrend != 0) TrendSignal = FixTrend;
    if      (TrendSignal ==  0) TrendText = "Range";
    else if (TrendSignal ==  1) TrendText = "Bullish";
    else if (TrendSignal == -1) TrendText = "Bearish";
    if (CommentSwitch == true) Comment("RSI[", TFstr_high, "]: ", DoubleToString(higher_rsi, 2), " Trend: ", TrendText,
                                       "\nRSI[", TFstr_current, "]: ", DoubleToString(rsi, 2),
                                       "\nInitial Lot: ", ShowOptimizedLot);
    //--- ポジションが存在する場合、逆シグナルでクローズ
    if (PositionsTotal() > 0 && CloseWithRSI == true)
    {
        if (CheckForOppositeSignal(close_signal))
        {
            CloseAllPositions();
            GridCount = 0;
            //return;
        }
    }
    datetime currentFrameBarTime = iTime(_Symbol, PERIOD_CURRENT, 0); // 新しい足が始まったかを確認
    if (currentFrameBarTime != lastFrameBarTime)
    {
       lastFrameBarTime = currentFrameBarTime;
       OrderedFlag = false; // Reset Flag
    }
    if (OrderedFlag) return;
    if (DontOpenAfter_SLTP == true) CheckSLTPClose();
    if (DontOpenAfter_SLTP == true && TimeCurrent() < pauseUntilTime)
    {
        //Print("Stop Trading Now: ", TimeToString(TimeCurrent()), "  Resume: ", TimeToString(pauseUntilTime));
        return;
    }
    //--- ポジションがない場合、シグナルに従ってエントリー
    if (PositionsTotal() == 0 && TrendSignal != 0 && rsi_signal != 0)
    {
        GridCount = 0;
        if (TrendFollowing == false)
        {
            if (TrendSignal == -1 && rsi_signal == -1) OrderBuy(); // Trend Sell, RSI OverSold → Buy
            else if (TrendSignal == 1 && rsi_signal == 1) OrderSell(); // Trend Buy RSI OverBought → Sell
        }
        if (TrendFollowing == true)
        {
            if (TrendSignal == 1 && rsi_signal == -1) OrderBuy(); // Trend Buy, RSI OverSold → Buy
            else if (TrendSignal == -1 && rsi_signal == 1) OrderSell(); // Trend Sell, RSI OverBought → Sell
        }
    }
}

//+------------------------------------------------------------------+
// 上位足のRSI値を取得し、Buy（1）、Sell（-1）、No Signal（0）を返す
int GetHigherRsiSignal()
{
    double higher_rsi_buffer[];
    if (CopyBuffer(higher_rsi_handle, 0, 0, 1, higher_rsi_buffer) <= 0)
    {
        Print("Failed to get higher RSI value");
        return 0;
    }
    higher_rsi = higher_rsi_buffer[0];
    if (higher_rsi < HigherRSISelling) return -1; // oversold: -1
    if (higher_rsi > HigherRSIBuying) return 1; // overbought: 1
    return 0;
}

//+------------------------------------------------------------------+
// RSI値を取得し、Buy（1）、Sell（-1）、No Signal（0）を返す
int GetRsiSignal()
{
    double rsi_buffer[];
    if (CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) <= 0)
    {
        Print("Failed to get current RSI value");
        return 0;
    }
    rsi = rsi_buffer[0];
    if (rsi < RsiOversold) return -1; // oversold: -1
    if (rsi > RsiOverbought) return 1; // overbought: 1
    return 0;
}
int GetCloseRsiSignal()
{
    double rsi_buffer[];
    if (CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) <= 0)
    {
        Print("Failed to current get RSI value");
        return 0;
    }
    rsi = rsi_buffer[0];
    if (rsi < RsiCloseSold) return -1; // close sold: -1
    if (rsi > RsiCloseBought) return 1; // close bought: 1
    return 0;
}

//+------------------------------------------------------------------+
// 逆シグナル判定（現在のポジションに対して）
bool CheckForOppositeSignal(int close_signal)
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetSymbol(i) == _Symbol)
        {
            long type;
            if (PositionGetInteger(POSITION_TYPE, type))
            {
                if ((type == POSITION_TYPE_BUY && close_signal == 1) ||
                    (type == POSITION_TYPE_SELL && close_signal == -1))
                {
                    Print("Opposite RSI signal detected");
                    return true;
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
// ポジションクローズ処理
void CloseAllPositions()
{
//    for (int i = PositionsTotal() - 1; i >= 0; i--)
//    {
//        if (PositionGetSymbol(i) == _Symbol)
//        {
//            long type = PositionGetInteger(POSITION_TYPE);
//            ulong ticket = PositionGetInteger(POSITION_TICKET);
//            if (type == POSITION_TYPE_BUY)
//                trade.PositionClose(_Symbol);
//            else if (type == POSITION_TYPE_SELL)
//                trade.PositionClose(_Symbol);
//        }
//    }
      for (int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if (!PositionSelectByTicket(ticket)) continue;
         string symbol = PositionGetString(POSITION_SYMBOL);
         long magic    = PositionGetInteger(POSITION_MAGIC);
         if (symbol != _Symbol || magic != MagicNumber) continue;
         Print("Closing Ticket: ", ticket);
         if (!trade.PositionClose(ticket))
         {
            Print("Failed to Close: ", ticket, " Reason: ", trade.ResultRetcode(), " / ", trade.ResultRetcodeDescription());
         }
      }
}

//+------------------------------------------------------------------+
// 最後の取引の利益を取得
void UpdateLastProfit(ulong magic)
{
    if (HistorySelect(TimeCurrent() - 86400 * 7, TimeCurrent()))
    {
        int deals = HistoryDealsTotal();
        for (int i = deals - 1; i >= 0; i--)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if (HistoryDealSelect(ticket))
            {
                string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
                long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
                int type = (int)HistoryDealGetInteger(ticket, DEAL_TYPE);
                if (symbol == _Symbol &&
                    deal_magic == (long)magic &&
                    (type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL))
                {
                    lastProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    break;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// マーチンゲールのロット調整
void AdjustLotSize()
{
    double FinalDynamicMultiplier = GetDynamicMultiplier();
    if (lastProfit < 0)
    {
        //currentMultiplier *= FinalDynamicMultiplier;
        currentMultiplier = FinalDynamicMultiplier;
        currentLot = GetDynamicLot(LotCoefficient) * currentMultiplier;
        currentLot = NormalizeLot(currentLot);
        Print("Loss detected, lot increased to ", currentLot);
    }
    else
    {
        //currentMultiplier = 1.00;
        currentMultiplier = FinalDynamicMultiplier;
        currentLot = GetDynamicLot(LotCoefficient) * currentMultiplier;
        currentLot = NormalizeLot(currentLot);
        ShowOptimizedLot = currentLot;
        Print("Profit or no trade, lot reset to ", currentLot);
    }
    //if (currentLot > MaxLot)
    //{
    //    currentLot = MaxLot;
    //    Print("Limited to ", MaxLot, " due to max lot limit.");
    //}
}

//+------------------------------------------------------------------+
// currentLot を常に有効な値に正規化するための関数
double NormalizeLot(double lot)
{
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);   // 最小ロット
    double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);  // ロットの刻み幅
    // 最小ロット以下なら補正
    lot = MathMax(lot, minLot);
    // ステップ単位に丸める
    lot = MathRound(lot / step) * step;
    return lot;
}

//+------------------------------------------------------------------+
// ロット倍率の増加率をロスカウントに応じて変化
double GetDynamicMultiplier()
{
    DynamicMultiplier = 0;
    DynamicMultiplier = MathPow(LotMultiplier, LossCountTrading());
    if (GridLotMultiplier > 0) DynamicMultiplier = MathPow(LotMultiplier, LossCountTrading()) * MathPow(GridLotMultiplier, GridCount);
    return DynamicMultiplier;
}

//+------------------------------------------------------------------+
// 初期ロットを資本に応じて変化
double GetDynamicLot(double coefficient)
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double lot = equity * coefficient / 1000;
    double MaxDynamicMultiplier = MathPow(LotMultiplier, MaxLossCount);
    // ロットをブローカー制限に合わせて調整
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX) / MaxDynamicMultiplier / MaxLotDivision;
    double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lot = MathMax(minLot, MathMin(maxLot, lot));
    lot = NormalizeDouble(lot / step, 0) * step;
    return lot;
}

//+------------------------------------------------------------------+
// ロスカット水準を監視してEAを停止
void CheckForStopByMarginLevel()
{
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    if (marginLevel > 0 && marginLevel < minMarginLevel)
    {
        minMarginLevel = marginLevel;
        Print("⚠ Minimum Margin Level Updated: ", DoubleToString(minMarginLevel, 2), " %");
    }
    if (marginLevel > 0 && marginLevel < StopEA_MarginLevel)
    {
        CloseAllPositions();
        Print("⛔ Magin Level under Limit: ", DoubleToString(marginLevel, 2), "%, EA Stopping...");
        ExpertRemove();  // EA Remove from Chart
    }
}

//+------------------------------------------------------------------+
// Count Loss Trading
int LossCountTrading()
{
   UpdateLastProfit(MagicNumber);
   if (lastProfit < 0 && LossCount < MaxLossCount && GridCount == 0) LossCount += 1;
   else if (lastProfit >= 0) LossCount = 0;
   return LossCount;
}


//+------------------------------------------------------------------+
// Timeframe to String
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return "M1";
      case PERIOD_M2:   return "M2";
      case PERIOD_M3:   return "M3";
      case PERIOD_M4:   return "M4";
      case PERIOD_M5:   return "M5";
      case PERIOD_M6:   return "M6";
      case PERIOD_M10:  return "M10";
      case PERIOD_M12:  return "M12";
      case PERIOD_M15:  return "M15";
      case PERIOD_M20:  return "M20";
      case PERIOD_M30:  return "M30";
      case PERIOD_H1:   return "H1";
      case PERIOD_H2:   return "H2";
      case PERIOD_H3:   return "H3";
      case PERIOD_H4:   return "H4";
      case PERIOD_H6:   return "H6";
      case PERIOD_H8:   return "H8";
      case PERIOD_H12:  return "H12";
      case PERIOD_D1:   return "D1";
      case PERIOD_W1:   return "W1";
      case PERIOD_MN1:  return "MN1";
      default:          return "Unknown";
   }
}

//+------------------------------------------------------------------+
// 現在保有中のポジションの中で、最後に開かれたポジションの取得価格を得る
double GetLastPositionPrice(string symbol, long magic, int type_filter)
{
    double last_price = 0;
    datetime latest_time = 0;

    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            string sym = PositionGetString(POSITION_SYMBOL);
            long   mg  = PositionGetInteger(POSITION_MAGIC);
            int    type = (int)PositionGetInteger(POSITION_TYPE);
            datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            if (sym == symbol && mg == magic && type == type_filter)
            {
                if (open_time > latest_time)
                {
                    latest_time = open_time;
                    last_price = PositionGetDouble(POSITION_PRICE_OPEN);
                }
            }
        }
    }
    return last_price;
}

//+------------------------------------------------------------------+
// 最後のポジションの取得価格からグリッドオーダーのためのポイントを計算
void GetGridPoint()
{
   if (last_pos_type == POSITION_TYPE_BUY)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double buy_last = GetLastPositionPrice(_Symbol, MagicNumber, POSITION_TYPE_BUY);
      GridBuyPoint = buy_last * (100 - GridDistance * MathPow(GridMultiplier, GridCount)) / 100;
   }
   else if (last_pos_type == POSITION_TYPE_SELL)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sell_last = GetLastPositionPrice(_Symbol, MagicNumber, POSITION_TYPE_SELL);
      GridSellPoint = sell_last * (100 + GridDistance * MathPow(GridMultiplier, GridCount)) / 100;
   }
}

//+------------------------------------------------------------------+
// New Order
void OrderBuy()
{
   AdjustLotSize();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = 0.0, tp = 0.0;
   if (StopLossPercentage == 0) sl = 0.0;
   else if (StopLossPercentage > 0) sl = ask * (100 - StopLossPercentage * MathPow(LossToRangeFactor,LossCount)) / 100;
   if (TakeProfitPercentage == 0) tp = 0.0;
   else if (TakeProfitPercentage > 0) tp = ask * (100 + TakeProfitPercentage * MathPow(LossToRangeFactor,LossCount)) / 100;
   if (trade.Buy(currentLot, _Symbol, ask, sl, tp, "RSI Brothers Buy")) OrderedFlag = true;
   //TrendSignal = 0; // Reset Trend Signal
   if (GridSwitch == true)
   {
      last_pos_type = POSITION_TYPE_BUY;
      GetGridPoint();
   }
}
void OrderSell()
{
   AdjustLotSize();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0.0, tp = 0.0;
   if (StopLossPercentage == 0) sl = 0.0;
   else if (StopLossPercentage > 0) sl = bid * (100 + StopLossPercentage * MathPow(LossToRangeFactor,LossCount)) / 100;
   if (TakeProfitPercentage == 0) tp = 0.0;
   else if (TakeProfitPercentage > 0) tp = bid * (100 - TakeProfitPercentage * MathPow(LossToRangeFactor,LossCount)) / 100;
   if (trade.Sell(currentLot, _Symbol, bid, sl, tp, "RSI Brothers Sell")) OrderedFlag = true;
   //TrendSignal = 0;
   if (GridSwitch == true)
   {
      last_pos_type = POSITION_TYPE_SELL;
      GetGridPoint();
   }
}

//+------------------------------------------------------------------+
// Checking SL/TP
void CheckSLTPClose()
{
    datetime now = TimeCurrent();
    datetime fromTime = now - PeriodSeconds(PERIOD_CURRENT);
    if (!HistorySelect(fromTime, now))
    {
        Print("SL/TP HistorySelect failed");
        return;
    }
    int totalDeals = HistoryDealsTotal();
    for (int i = totalDeals - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (ticket == LastCheckedDeal) break;  // これが重要
        if (!HistoryDealSelect(ticket)) continue;
        string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
        long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
        long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
        long reason = HistoryDealGetInteger(ticket, DEAL_REASON);
        // このEAのクローズ取引かつSLまたはTPなら
        if (symbol == _Symbol &&
            dealMagic == MagicNumber &&
            entryType == DEAL_ENTRY_OUT &&
            (reason == DEAL_REASON_SL || reason == DEAL_REASON_TP))
        {
            datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
            int tfSec = PeriodSeconds(PERIOD_CURRENT);
            pauseUntilTime = barTime + tfSec;
            LastCheckedDeal = ticket;  // 直近で拾った取引を記録
            Print("Last Deal closed via SL/TP, Pause until Next Bar: ", pauseUntilTime);
            break;
        }
    }
}
