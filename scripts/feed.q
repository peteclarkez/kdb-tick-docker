/ Feed Handler - publishes trade and quote data to tickerplant
/ q feed.q [tp_port] -p port
/ e.g., q feed.q ::5010

/ This file should be placed in /scripts/feed.q
/ It will be started automatically by tick.sh if present

/ Load schema from /scripts mount point
scriptsDir:$[count s:getenv`TICK_SCRIPTS_DIR;s;"/scripts"];
system"l ",scriptsDir,"/sym.q"

/ Connect to tickerplant
/ Port can be passed as command line argument (e.g., q feed.q ::5010)
/ Defaults to localhost:5010 if not provided
tp:$[count .z.x;`$first .z.x;`::5010];
h:hopen tp;
-1 "Connected to tickerplant at ",string tp;

/ Configuration
r:20;       / number of rows to send in each update
u:2;        / number of updates to send per timer tick
t:10000;    / timer frequency (milliseconds)

\g 1        / Set garbage mode to immediate

/ Sample symbols for realistic data
syms:`AAPL`MSFT`GOOG`AMZN`META`TSLA`NVDA`AMD`INTC`IBM;

/ Track last prices for each symbol (for realistic price movement)
lastPrices:syms!100.0 350.0 140.0 180.0 500.0 250.0 800.0 150.0 35.0 140.0;

/ Create trade data with realistic prices
/ Returns: (time; sym; price; size)
createTradeData:{[n]
  s:n?syms;
  / Get base prices and add random walk
  p:lastPrices[s] * 1 + (n?0.02) - 0.01;
  / Update last prices (use amend to update dictionary)
  lastPrices::lastPrices,s!p;
  (n#.z.p; s; p; 10*1+n?100)
 };

/ Create quote data with realistic bid/ask spread
/ Returns: (time; sym; bid; ask; bsize; asize)
createQuoteData:{[n]
  s:n?syms;
  / Get mid prices
  mid:lastPrices[s] * 1 + (n?0.001) - 0.0005;
  / Spread varies by symbol "liquidity" (0.01% to 0.1%)
  spread:mid * 0.0001 + n?0.001;
  bid:mid - spread % 2;
  ask:mid + spread % 2;
  (n#.z.p; s; bid; ask; 100*1+n?50; 100*1+n?50)
 };

/ Publish counter for alternating between trade and quote
pubCount:0;

/ Timer function - publishes both trades and quotes
.z.ts:{
  / Alternate: 2 trade batches, then 1 quote batch
  tbl:$[2>pubCount mod 3;`trade;`quote];
  data:$[tbl=`trade;createTradeData[r];createQuoteData[r]];
  if[r=1;data:first each data];
  do[u;neg[h](`.u.upd;tbl;data);neg[h][]];
  pubCount+:1;
 };

/ Start timer
system"t ",string t;
-1 "Feed handler started - publishing trades and quotes every ",string[t],"ms";

/ Stop sending data if connection to tickerplant is lost
.z.pc:{if[x=h; system"t 0"; -1 "Tickerplant connection lost - feed stopped"]};
