/ Table schemas for kdb+tick
/ This file must be mounted at /scripts/sym.q
/ Customize for your data requirements

/ Quote table schema
quote:([]
  time:`timestamp$();
  sym:`symbol$();
  bid:`float$();
  ask:`float$();
  bsize:`int$();
  asize:`int$())

/ Trade table schema
trade:([]
  time:`timestamp$();
  sym:`symbol$();
  price:`float$();
  size:`int$())
