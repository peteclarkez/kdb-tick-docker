/ Custom RDB Functions
/ This file is loaded by the RDB if present at /scripts/rdb_custom.q
/ Add your custom real-time analytics and functions here

/ Example: Get last trade for each symbol
lastTrades:{select last time, last price, last size by sym from trade};

/ Example: Get current spread from quotes
currentSpread:{select sym, spread:ask-bid, mid:0.5*bid+ask from (select last bid, last ask by sym from quote)};

/ Example: Get trade summary statistics
tradeSummary:{
  select
    trades:count i,
    volume:sum size,
    turnover:sum price*size,
    vwap:size wavg price,
    low:min price,
    high:max price
  by sym from trade
 };

-1 "Custom RDB functions loaded";
