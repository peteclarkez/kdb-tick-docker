/ Custom Gateway Functions
/ This file is loaded by the Gateway if present at /scripts/gw_custom.q
/ Add your custom cross-database analytics and functions here


/=============================================================================
/ QUERY FUNCTIONS - Unified access to RDB and HDB
/=============================================================================

/ Get trade data across date range for specified symbols
/ sd: start date (date type)
/ ed: end date (date type)
/ ids: symbol list or ` for all symbols
/ Returns: combined data from HDB (historical) and RDB (today)
getTradeData:{[sd;ed;ids]
  result:();
  / Query HDB if date range includes historical dates
  if[sd<.z.D;
    if[not null h:connectHDB[];
      hdb_data:@[h;(`selectFunc;`trade;sd;min(ed;.z.D-1);ids);{-1 "HDB query error: ",x;()}];
      if[count hdb_data; result:result,hdb_data]]];
  / Query RDB if date range includes today
  if[ed>=.z.D;
    if[not null h:connectRDB[];
      rdb_data:@[h;(`selectFunc;`trade;sd;ed;ids);{-1 "RDB query error: ",x;()}];
      if[count rdb_data; result:result,rdb_data]]];
  `time xasc result};

/ Get quote data across date range for specified symbols
getQuoteData:{[sd;ed;ids]
  result:();
  if[sd<.z.D;
    if[not null h:connectHDB[];
      hdb_data:@[h;(`selectFunc;`quote;sd;min(ed;.z.D-1);ids);{-1 "HDB query error: ",x;()}];
      if[count hdb_data; result:result,hdb_data]]];
  if[ed>=.z.D;
    if[not null h:connectRDB[];
      rdb_data:@[h;(`selectFunc;`quote;sd;ed;ids);{-1 "RDB query error: ",x;()}];
      if[count rdb_data; result:result,rdb_data]]];
  `time xasc result};



/=============================================================================
/ CONVENIENCE FUNCTIONS
/=============================================================================


/ Get available symbols from RDB
getSymbols:{
  if[null h:connectRDB[];:`symbol$()];
  @[h;"distinct exec sym from trade";{`symbol$()}]};

/ Get today's trades for symbols
getTodayTrades:{[ids] getTradeData[.z.D;.z.D;ids]};

/ Get today's quotes for symbols
getTodayQuotes:{[ids] getQuoteData[.z.D;.z.D;ids]};

/ Get last N days of trade data for symbols
getRecentTrades:{[days;ids] getTradeData[.z.D-days;.z.D;ids]};

/ Get last N days of quote data for symbols
getRecentQuotes:{[days;ids] getQuoteData[.z.D-days;.z.D;ids]};

/ Get all trades for a single symbol between dates
getSymTrades:{[sym;sd;ed] getTradeData[sd;ed;enlist sym]};

/ Get VWAP (Volume Weighted Average Price) for symbols between dates
getVWAP:{[sd;ed;ids]
  trades:getTradeData[sd;ed;ids];
  select vwap:size wavg price, total_volume:sum size, trade_count:count i
    by date,sym from trades};

/ Get OHLC (Open, High, Low, Close) for symbols between dates
getOHLC:{[sd;ed;ids]
  trades:getTradeData[sd;ed;ids];
  select open:first price, high:max price, low:min price, close:last price,
         volume:sum size, trades:count i
    by date,sym from trades};



/=============================================================================
/ CUSTOM FUNCTIONS
/=============================================================================

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


-1 "";
-1 "=== Custom Gateway Functions Loaded ===";
-1 "";
-1 "Available functions:";
-1 "  Query:";
-1 "    getTradeData[sd;ed;ids]  - Get trades between dates for symbols";
-1 "    getQuoteData[sd;ed;ids]  - Get quotes between dates for symbols";
-1 "    getData[tbl;sd;ed;ids]   - Generic table query";
-1 "    getTodayTrades[ids]      - Today's trades";
-1 "    getTodayQuotes[ids]      - Today's quotes";
-1 "    getRecentTrades[days;ids]- Last N days of trades";
-1 "  Analytics:";
-1 "    getVWAP[sd;ed;ids]       - Volume weighted average price";
-1 "    getOHLC[sd;ed;ids]       - Open/High/Low/Close bars";
-1 "";
-1 "Example: getTradeData[.z.D-7;.z.D;`AAPL`MSFT]";

-1 "Custom Gateway functions loaded";
