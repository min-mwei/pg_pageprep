# pg_pageprep

**WIP**

`pg_pageprep` is an extension that is supposed to help to prepare heap pages for migration to 64bit XID page format.

PostgresPro Enterprise page format reqiures extra 24 bytes per page compared to original PostgreSQL in order to support 64bit transaction IDs. The idea behind this extension is to prepare enough space in pages for new format while database is working on vanilla postgres.

# Installation

```
make install USE_PGXS=1
```

or if postgres binaries are not on PATH

```
make install USE_PGXS=1 PG_CONFIG=/path/to/pg_config
```

After that perform `CREATE EXTENSION pg_pageprep;` on each database in cluster.

# Configuration

You can add the following parameters to your postgres config:

* `pg_pageprep.databases` - comma separated list of databases (default 'postgres');
* `pg_pageprep.role` - user name (default 'postgres');
* `pg_pageprep.per_page_delay` - delay between consequent page scans in milliseconds (default 100ms);
* `pg_pageprep.per_relation_delay` - delay b/w relations scans in milliseconds (default 1000ms);
* `pg_pageprep.per_attempt_delay` - delay b/w attempts to scan next relation in case previous attempt was unsuccessful, e.g. there are all relations are already done (default 60s).

# Usage

## Python script

```
python manager.py -d <database_list> -U <username> <command>
```

where `<database_list>` is a comma-separated list of databases, `<username>` is a user name on whose behalf the script will work and `command` is one of the following:

* install - creates extension on each database listed, adds pg_pageprep.databases and pg_pageprep.role parameters to config (ALTER SYSTEM). Note that background workers will start automatically after next cluster restart.
* start - starts background workers right away;
* stop - stops background workers;
* status - shows information about current workers activity and relations to be processed;
* restore - stop workers (if any) and restore original fillfactor (this is usually need to be done after pg_upgrade).

Example:

```
python manager.py -d my_database1,my_database2 -U my_username status
```

> **Note:** If pg_config isn't on your path you'll need to set PG_CONFIG environment variable:
> `PG_CONFIG=/path/to/pg_config python manager.py -d my_database1,my_database2 -U my_username status`

## plpgsql

On every database perform:

```
CREATE EXTENSION pg_pageprep;
SELECT start_bgworker();
```

To check todo list use view:

```
SELECT * FROM pg_pageprep_todo;
```

The empty list means that everything is done and database is ready for pg_upgrade.
To view current workers status use function `get_workers_list()`:

```
SELECT * FROM get_workers_list();

 database | status 
----------+--------
 postgres | active
(1 row)

```

Use following function to stop background worker:

```
SELECT start_bgworker();
```

This only stops worker on current database.
