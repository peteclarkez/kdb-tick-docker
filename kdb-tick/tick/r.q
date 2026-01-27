/q tick/r.q [host]:port[:usr:pwd] [host]:port[:usr:pwd]
/2008.09.09 .k ->.q

if[not "w"=first string .z.o;system "sleep 1"];

upd:insert;

/ get the ticker plant and history ports, defaults are 5010,5012
.u.x:.z.x,(count .z.x)_(":5010";":5012");

/ Get HDB directory from environment, default to /data
/ This is where EOD data will be saved
.u.hdbDir:`$":",$[count d:getenv`TICK_HDB_DIR;d;"/data"];

/ end of day: save to explicit HDB directory, clear, hdb reload
.u.end:{t:tables`.;t@:where `g=attr each t@\:`sym;.Q.hdpf[`$":",.u.x 1;.u.hdbDir;x;`sym];@[;`sym;`g#] each t;};

/ init schema and sync up from log file
/ Note: removed cd command - RDB saves to explicit .u.hdbDir path
.u.rep:{(.[;();:;].)each x;if[null first y;:()];-11!y};

/ connect to ticker plant for (schema;(logcount;log))
.u.rep .(hopen `$":",.u.x 0)"(.u.sub[`;`];`.u `i`L)";

/ Gateway access function - query data by date range and symbols
/ tbl: table name (e.g. `trade)
/ sd: start date
/ ed: end date
/ ids: list of symbols (pass ` for all)
selectFunc:{[tbl;sd;ed;ids]
  $[`date in cols tbl;
    / If table has date column, filter by date range and symbols
    $[ids~`;
      select from tbl where date within (sd;ed);
      select from tbl where date within (sd;ed), sym in ids];
    / RDB table (no date column) - add today's date and filter
    [res:$[.z.D within (sd;ed);
        $[ids~`; select from tbl; select from tbl where sym in ids];
        0#value tbl];
      `date xcols update date:.z.D from res]
  ]
 };

/ Manual end-of-day trigger for testing HDB persistence
/ Saves current day's data to HDB and clears RDB tables
/ WARNING: This will clear all in-memory data!
triggerEOD:{
  -1 "Triggering manual end-of-day save for date: ",string .u.d;
  -1 "Saving to HDB directory: ",1_string .u.hdbDir;
  -1 "Tables to save: ",", " sv string tables`.;
  -1 "Trade count: ",string count trade;
  -1 "Quote count: ",string count quote;
  .u.end[.u.d];
  -1 "End-of-day complete - data saved to HDB";
  `ok
 };

/ Get current RDB statistics
rdbStats:{
  `date`trade_count`quote_count`hdb_dir`tables!(.u.d;count trade;count quote;1_string .u.hdbDir;tables`.)
 };

/ Load custom RDB functions from /scripts if available
scriptsDir:$[count s:getenv`TICK_SCRIPTS_DIR;s;"/scripts"];
customRdb:scriptsDir,"/rdb_custom.q";
if[(hsym`$customRdb)~key hsym`$customRdb;
  -1 "Loading custom RDB functions from ",customRdb;
  system"l ",customRdb];

-1 "RDB ready - HDB save directory: ",1_string .u.hdbDir;
