
\l tick/sym.q

// connect to tickerplant
// Port can be passed as command line argument (e.g., q feed.q :5010)
// Defaults to localhost:5010 if not provided
tp:$[count .z.x;`$first .z.x;`::5010];
h:hopen tp;
// number of rows to send in each update
r:20;
// number of updates to send per millisecond
u:2;
// timer frequency
t:10000;

\g 1 // Set garbage mode to immediate

// Name of table to publish;
tname:`trade;

/ timer function, sends data to the tickerplant

.z.ts:{
    data:$[`trade=tname;createTradeData[r];createTelData[r]];
    if[r=1;data:first each data];
    do[u;neg[h](`.u.upd;tname;data);neg[h][]];
  };
system"t ",string t
/ stop sending data if connection to tickerplant is lost
.z.pc:{if[x=h; system"t 0"];}

createTradeData:{[x]    :(x#.z.p;x?`3;100*x?1.0;10*x?100); };