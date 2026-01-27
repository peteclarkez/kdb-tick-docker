/ Custom HDB Functions
/ This file is loaded by the HDB if present at /scripts/hdb_custom.q
/ Add your custom historical analytics and functions here

/ Example: Daily VWAP for given date and symbols
dailyVWAP:{[dt;syms]
  $[syms~`;
    select vwap:size wavg price, volume:sum size by sym from trade where date=dt;
    select vwap:size wavg price, volume:sum size by sym from trade where date=dt, sym in syms]
 };

/ Example: Get OHLC for a date range
dailyOHLC:{[sd;ed;syms]
  $[syms~`;
    select open:first price, high:max price, low:min price, close:last price, volume:sum size
      by date, sym from trade where date within (sd;ed);
    select open:first price, high:max price, low:min price, close:last price, volume:sum size
      by date, sym from trade where date within (sd;ed), sym in syms]
 };

/ Example: Get date range available in HDB
dateRange:{(min date;max date)};

-1 "Custom HDB functions loaded";
