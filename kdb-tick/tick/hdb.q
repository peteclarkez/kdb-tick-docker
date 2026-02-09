/ q tick/hdb.q [hdb_dir] -p 5012
/ Historical Database loader and query server
/ Loads date-partitioned historical data and provides query interface for gateway

/ Check for HDB directory argument
if[1>count .z.x;
  -1 "Usage: q tick/hdb.q [hdb_directory] -p 5012";
  -1 "  hdb_directory: path to historical database (e.g., /data/tick)";
  exit 1];

hdb:.z.x 0;

/ Mount the Historical Date Partitioned Database
/ Note: This may fail if no data exists yet - that's OK, we'll start empty
loaded:@[{system "l ",x;1b}; hdb; {-1 "Note: No historical data found (this is normal on first run)";0b}];

-1 "HDB directory: ",hdb;
-1 "Tables available: ",", " sv string tables`.;
if[loaded and `date in key `.;
  -1 "Date range: ",string[min date]," to ",string max date];

/ Gateway access function - query data by date range and symbols
/ tbl: table name (e.g. `trade)
/ sd: start date
/ ed: end date
/ ids: list of symbols (pass ` for all)
selectFunc:{[tbl;sd;ed;ids]
  / Return empty if table doesn't exist
  if[not tbl in tables`.;:()];
  $[`date in cols tbl;
    / Partitioned table - filter by date range and symbols
    $[ids~`;
      select from tbl where date within (sd;ed);
      select from tbl where date within (sd;ed), sym in ids];
    / Non-partitioned table
    [res:$[ids~`; select from tbl; select from tbl where sym in ids];
      `date xcols update date:.z.D from res]
  ]
 };

/ Utility function to list available dates
getDates:{$[`date in key `.;asc distinct date;`date$()]};

/ Utility function to list available symbols
getSyms:{$[`trade in tables`.;asc distinct exec sym from trade;`symbol$()]};

/ Utility function to get table schema
getSchema:{[tbl] $[tbl in tables`.;meta tbl;()]};

/ Load custom HDB functions from /scripts if available
scriptsDir:$[count s:getenv`TICK_SCRIPTS_DIR;s;"/scripts"];
customHdb:scriptsDir,"/hdb_custom.q";
if[(hsym`$customHdb)~key hsym`$customHdb;
  -1 "Loading custom HDB functions from ",customHdb;
  system"l ",customHdb];

-1 "HDB ready on port ",string system "p";
