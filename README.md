# RSI_Brothers
Customizable multi-timeframe RSIs based Expert-Advisor (EA) for Metatrader5 (MT5) algorithmic trading, optional grid-mode and martingale-mode is also available.  
  
---- Set Up ----  
Trend Following = true:  
Longer RSI Signal Bullish and Current RSI Oversold -> Buy,  
Longer RSI Signal Bearish and Current RSI Overbought -> Sell.  
Trend Following = false:  
Longer RSI Signal Bullish and Current RSI Overbought -> Sell,  
Longer RSI Signal Bearish and Current RSI Oversold -> Buy.  
  
---- Lot Calculation ----  
Initial Lot = Equity * Coefficient Value * / 1000  
The Maximum Initial Lot Size is Calculated based on the Lot Multiplier, Loss Count, Division Value.  
  
<img alt="preview1" src="https://github.com/mitsuaki-41/RSI_Brothers/blob/main/preview1.png?raw=true" width="842" />  
  
---- Tips ----　　
EA was Tested on XAUUSD M10.  
By default, it's tuned for M10 XAUUSD. (There might be another better balance.)  
My FX account is based on Japanese Yen, so to convert it to USD, You need to multiply the Coefficient Value by approximately 150.　
When MT5 restarts, the Longer RSI trend is reset to the Initial-Trend-Signal value. Therefore, if you can recognize that the Longer RSI is within a trend at that time, you need to manually set the Initial-Trend-Signal value.  
  
<img alt="preview2" src="https://github.com/mitsuaki-41/RSI_Brothers/blob/main/preview2.png?raw=true" width="515" />  
