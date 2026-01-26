/ q tick/gw.q [rdb_port] [hdb_port] -p 5013
/ Gateway process - provides unified access to RDB and HDB
/ Combines real-time and historical data queries

/ Parse command line arguments for connection ports
args:.z.x,(count .z.x)_(":5011";":5012");
rdb_port:args 0;
hdb_port:args 1;

/ Connection handles (initialized as null, connected on demand)
h_rdb:0N;
h_hdb:0N;

/ Connect to RDB
connectRDB:{
  if[null h_rdb;
    h_rdb::@[hopen;`$":",rdb_port;{-1 "RDB connection failed: ",x;0N}]];
  h_rdb};

/ Connect to HDB
connectHDB:{
  if[null h_hdb;
    h_hdb::@[hopen;`$":",hdb_port;{-1 "HDB connection failed: ",x;0N}]];
  h_hdb};

/ Reconnect on connection close
.z.pc:{[handle]
  if[handle=h_rdb; h_rdb::0N; -1 "RDB disconnected"];
  if[handle=h_hdb; h_hdb::0N; -1 "HDB disconnected"]};

/ Initialize connections
-1 "Connecting to RDB on port ",rdb_port,"...";
connectRDB[];
-1 "Connecting to HDB on port ",hdb_port,"...";
connectHDB[];

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

/ Generic table query function
/ tbl: table name (`trade, `quote, etc)
/ sd: start date
/ ed: end date
/ ids: symbol list or ` for all
getData:{[tbl;sd;ed;ids]
  result:();
  if[sd<.z.D;
    if[not null h:connectHDB[];
      hdb_data:@[h;(`selectFunc;tbl;sd;min(ed;.z.D-1);ids);{-1 "HDB query error: ",x;()}];
      if[count hdb_data; result:result,hdb_data]]];
  if[ed>=.z.D;
    if[not null h:connectRDB[];
      rdb_data:@[h;(`selectFunc;tbl;sd;ed;ids);{-1 "RDB query error: ",x;()}];
      if[count rdb_data; result:result,rdb_data]]];
  `time xasc result};

/=============================================================================
/ CONVENIENCE FUNCTIONS
/=============================================================================

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
/ STATUS AND UTILITY FUNCTIONS
/=============================================================================

/ Check connection status
status:{
  `rdb`hdb!(not null h_rdb;not null h_hdb)};

/ Get available symbols from RDB
getSymbols:{
  if[null h:connectRDB[];:`symbol$()];
  @[h;"distinct exec sym from trade";{`symbol$()}]};

/ Get date range from HDB
getDateRange:{
  if[null h:connectHDB[];:()];
  @[h;"(min date;max date)";{()}]};

/ Ping both connections
ping:{
  rdb_ok:$[null h_rdb;0b;1~@[h_rdb;"1";0]];
  hdb_ok:$[null h_hdb;0b;1~@[h_hdb;"1";0]];
  `rdb`hdb!(rdb_ok;hdb_ok)};

/ Reconnect to both databases
reconnect:{
  h_rdb::0N; h_hdb::0N;
  connectRDB[];
  connectHDB[];
  status[]};

-1 "";
-1 "=== Gateway Ready ===";
-1 "Port: ",string system "p";
-1 "RDB: ",rdb_port," (connected: ",string[not null h_rdb],")";
-1 "HDB: ",hdb_port," (connected: ",string[not null h_hdb],")";
-1 "";
-1 "Available functions:";
-1 "  getTradeData[sd;ed;ids]  - Get trades between dates for symbols";
-1 "  getQuoteData[sd;ed;ids]  - Get quotes between dates for symbols";
-1 "  getData[tbl;sd;ed;ids]   - Generic table query";
-1 "  getTodayTrades[ids]      - Today's trades";
-1 "  getRecentTrades[days;ids]- Last N days of trades";
-1 "  getVWAP[sd;ed;ids]       - Volume weighted average price";
-1 "  getOHLC[sd;ed;ids]       - Open/High/Low/Close bars";
-1 "  status[]                 - Connection status";
-1 "  reconnect[]              - Reconnect to RDB/HDB";
-1 "";
-1 "Example: getTradeData[.z.D-7;.z.D;`AAPL`MSFT]";
