# How to split the Redlist version from BWARS

## Disconnect all from the bwars database

Can't do any database modifications while someone is connected

## Clone the BWARS database

From the `postgres` database, run `CREATE DATABASE redlist WITH TEMPLATE bwars;`

## Change to Redlist database

The following commands are run from the Redlist database

## Import any Redlist-only data

Use `bash/import_data.sh`. Make sure to run from the `bash` folder as per BWARS_sql instructions.

## Note which failed to import

iRecord's lack of normalisation is causing MASSIVE amounts of data to be refused on the grounds of self-replication, running as high as 60% in things like the bee walk. Dealing with this is going to be a major challenge that is not possible to complete in this project.

Final replication level is 27%