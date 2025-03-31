CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) x;

-- duration  39 secs 411 msec
--The table is created with 10 million rows and total space consumeed 575MB 
SELECT *, pg_size_pretty(total_bytes) AS total,
                pg_size_pretty(index_bytes) AS INDEX,
                pg_size_pretty(toast_bytes) AS toast,
                pg_size_pretty(table_bytes) AS TABLE
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid, nspname AS table_schema,
                       relname AS TABLE_NAME,
                       c.reltuples AS row_estimate,
                       pg_total_relation_size(c.oid) AS total_bytes,
                       pg_indexes_size(c.oid) AS index_bytes,
                       pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

--total_bytes 602415104
--index bytes 0
--toast_bytes 8192 
--table_bytes 602406912
--total 575MB

DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;

--DELETE 3333333- Query returned successfully in 30 secs 416 msec.
--total_bytes 602554368
--toast_bytes 8192 
--table_bytes 602554368
--total 575MB

-- After the DELETE operation, the total space used by the table increases slightly to 575 MB. The DELETE operation removed 1/3 of the rows (approximately 3,333,333 rows), but due to PostgreSQL's MVCC (Multi-Version Concurrency Control) system, deleted rows are not immediately reclaimed. Thus, the space used remains nearly the same, and no reduction in space is observed yet.


VACUUM FULL VERBOSE table_to_delete;
-- found 2907200 removable, 6666667 nonremovable row versions in 73536 pages 
--Query returned successfully in 13 secs 575 msec.
--The VACUUM FULL operation takes 13 seconds to reclaim space and remove 2.9 million removable rows, showing the cleanup of space left by the DELETE operation.
--total_bytes 401580032
--index bytes 0
--toast_bytes 8192 
--table_bytes 401571840
--total 383MB
--After running the VACUUM FULL command, space previously marked for deletion is reclaimed, resulting in a reduction of total space usage to about 383 MB (from 575 MB). This operation successfully freed up space occupied by the deleted rows, reducing the total size of the table by approximately 192 MB. However, the toast space remains the same, indicating that the space used for large objects (if any) did not change.

TRUNCATE table_to_delete;
--Query returned successfully in 1 secs 83 msec.
--The TRUNCATE operation is much faster than DELETE because it removes all rows instantly without the overhead of scanning individual rows or leaving space for future reuse.
--his operation leaves only the toast space (8 KB), showing that the table itself has been completely emptied, and no other data remains.
--total_bytes 8192
--index bytes 0
--toast_bytes 8192 
--table_bytes 0
--total 8192 bytes
