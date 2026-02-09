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

/=============================================================================
/ HDB PERSISTENCE FUNCTIONS
/=============================================================================

/ Get RDB statistics (record counts, current date)
rdbStats:{
  if[null h:connectRDB[];:()];
  @[h;"rdbStats[]";{-1 "RDB stats error: ",x;()}]};

/ Trigger manual end-of-day save
/ This saves RDB data to HDB and clears RDB tables
/ WARNING: Use with caution - this will clear all RDB in-memory data!
triggerEOD:{
  -1 "Requesting end-of-day save from RDB...";
  if[null h:connectRDB[];:-1 "Error: Cannot connect to RDB";`error];
  res:@[h;"triggerEOD[]";{-1 "EOD error: ",x;`error}];
  if[res~`ok;
    -1 "EOD complete - reconnecting to HDB to pick up new data...";
    h_hdb::0N;
    connectHDB[]];
  res};

/ Reload HDB (useful after manual data changes)
reloadHDB:{
  if[null h:connectHDB[];:-1 "Error: Cannot connect to HDB";`error];
  @[h;"system\"l .\"";{-1 "HDB reload error: ",x;`error}]};

/ Load custom Gateway functions from /scripts if available
scriptsDir:$[count s:getenv`TICK_SCRIPTS_DIR;s;"/scripts"];
customGw:scriptsDir,"/gw_custom.q";
if[(hsym`$customGw)~key hsym`$customGw;
  -1 "Loading custom Gateway functions from ",customGw;
  system"l ",customGw];

-1 "";
-1 "=== Gateway Ready ===";
-1 "Port: ",string system "p";
-1 "RDB: ",rdb_port," (connected: ",string[not null h_rdb],")";
-1 "HDB: ",hdb_port," (connected: ",string[not null h_hdb],")";
-1 "";
-1 "Available functions:";
-1 "  Admin:";
-1 "    status[]                 - Connection status";
-1 "    reconnect[]              - Reconnect to RDB/HDB";
-1 "    rdbStats[]               - RDB record counts and date";
-1 "    triggerEOD[]             - Manual end-of-day save (saves RDB to HDB)";
-1 "    reloadHDB[]              - Reload HDB data";
-1 "";
-1 "Example: getTradeData[.z.D-7;.z.D;`AAPL`MSFT]";
