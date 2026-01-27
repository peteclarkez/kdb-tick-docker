/ Custom Gateway Functions
/ This file is loaded by the Gateway if present at /scripts/gw_custom.q
/ Add your custom cross-database analytics and functions here

/ Example: Get intraday price range for today
intradayRange:{[syms]
  trades:getTodayTrades[syms];
  select low:min price, high:max price, range:max[price]-min price by sym from trades
 };

/ Example: Compare today's VWAP to historical average
vwapComparison:{[days;syms]
  today:getVWAP[.z.D;.z.D;syms];
  hist:getVWAP[.z.D-days;.z.D-1;syms];
  avgHist:select avg_vwap:avg vwap by sym from hist;
  (uj/)(today;avgHist)
 };

-1 "Custom Gateway functions loaded";
