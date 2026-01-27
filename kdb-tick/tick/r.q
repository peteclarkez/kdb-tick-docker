/q tick/r.q [host]:port[:usr:pwd] [host]:port[:usr:pwd]
/2008.09.09 .k ->.q

if[not "w"=first string .z.o;system "sleep 1"];

upd:insert;

/ get the ticker plant and history ports, defaults are 5010,5012
.u.x:.z.x,(count .z.x)_(":5010";":5012");

/ end of day: save, clear, hdb reload
.u.end:{t:tables`.;t@:where `g=attr each t@\:`sym;.Q.hdpf[`$":",.u.x 1;`:.;x;`sym];@[;`sym;`g#] each t;};

/ init schema and sync up from log file;cd to hdb(so client save can run)
.u.rep:{(.[;();:;].)each x;if[null first y;:()];-11!y;system "cd ",1_-10_string first reverse y};
/ HARDCODE \cd if other than logdir/db

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

