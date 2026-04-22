# RSI_Brothers
Customizable multi-timeframe RSIs based Expert-Advisor (EA) for Metatrader5 (MT5) algorithmic trading, optional grid-mode and martingale-mode is also available.  
  
---- Set Up ----  
Trend Following = true, Idiotical Mode = false:  
&emsp;Longer RSI Signal Bullish and Current RSI Oversold -> Buy,  
&emsp;Longer RSI Signal Bearish and Current RSI Overbought -> Sell.  
Trend Following = false, Idiotical Mode = false:  
&emsp;Longer RSI Signal Bullish and Current RSI Overbought -> Sell,  
&emsp;Longer RSI Signal Bearish and Current RSI Oversold -> Buy.  
Trend Following = true, Idiotical Mode = true:  
&emsp;Longer RSI Signal Bullish and Current RSI Oversold -> Sell,  
&emsp;Longer RSI Signal Bearish and Current RSI Overbought -> Buy.  
Trend Following = false, Idiotical Mode = true:  
&emsp;Longer RSI Signal Bullish and Current RSI Overbought -> Buy,  
&emsp;Longer RSI Signal Bearish and Current RSI Oversold -> Sell. 
  
---- Lot Calculation ----  
Initial Lot = Equity * Coefficient Value * / 1000  
The Maximum Initial Lot Size is Calculated based on the Lot Multiplier, Loss Count, Division Value.  
  
<img alt="preview1" src="https://github.com/mitsuaki-41/RSI_Brothers/blob/main/preview1.png?raw=true" width="837" />  
  
---- Tips ----  
EA was Tested on M10 XAUUSD.  
By default, it's tuned for M10 XAUUSD. (There might be another better balance.)  
My FX account equity is based on Japanese Yen, so to convert it to USD, you need to multiply the Coefficient Value by approximately 150.  
When MT5 restarts, a Longer RSI Signal is reset to Initial-Trend-Signal value. Therefore, if you can recognize that a Longer RSI Signal is within a trend at that time, you need to manually set a Initial-Trend-Signal value.  
  
<img alt="preview2" src="https://github.com/mitsuaki-41/RSI_Brothers/blob/main/preview2.png?raw=true" width="515" />  
