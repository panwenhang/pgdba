WITH data_lag AS (
    SELECT
    	application_name,
    	client_addr,
    	cur_xlog || '/' || cur_offset AS cur_xlog,
    	sent_xlog || '/' || sent_offset AS sent_xlog,
    	replay_xlog || '/' || replay_offset AS replay_xlog,
    	pg_size_pretty(( ((cur_xlog * 255 * 16 ^ 6) + cur_offset) - ((sent_xlog * 255 * 16 ^ 6) + sent_offset) )::numeric) AS master_lag,
    	pg_size_pretty(( ((sent_xlog * 255 * 16 ^ 6) + sent_offset) - ((replay_xlog * 255 * 16 ^ 6) + replay_offset) )::numeric) AS slave_lag,
    	pg_size_pretty(( ((cur_xlog * 255 * 16 ^ 6) + cur_offset) - ((replay_xlog * 255 * 16 ^ 6) + replay_offset) )::numeric) AS total_lag
    FROM (
    	SELECT
    		application_name,
    		client_addr,
    		('x' || lpad(split_part(sent_location::text,'/', 1), 8, '0'))::bit(32)::bigint AS sent_xlog,
    		('x' || lpad(split_part(replay_location::text, '/', 1), 8, '0'))::bit(32)::bigint AS replay_xlog,
    		('x' || lpad(split_part(sent_location::text, '/', 2), 8, '0'))::bit(32)::bigint AS sent_offset,
    		('x' || lpad(split_part(replay_location::text, '/', 2), 8, '0'))::bit(32)::bigint AS replay_offset,
    		('x' || lpad(split_part(pg_current_xlog_location()::text, '/', 1), 8, '0'))::bit(32)::bigint AS cur_xlog,
    		('x' || lpad(split_part(pg_current_xlog_location()::text, '/', 2), 8, '0'))::bit(32)::bigint AS cur_offset
    	FROM
		    pg_stat_replication
        ) AS s 
    ),
pg_lag AS (
    SELECT
        client_addr,
        application_name,
        pg_size_pretty(pg_xlog_location_diff(sent_location, write_location)) AS network_delay,
        pg_size_pretty(pg_xlog_location_diff(write_location, flush_location)) AS slave_write,
        pg_size_pretty(pg_xlog_location_diff(flush_location, replay_location)) AS slave_replay,
        pg_size_pretty(pg_xlog_location_diff(pg_current_xlog_location(), replay_location)) AS total_delay
    FROM
        pg_stat_replication
),
time_lag AS (
	SELECT now() - pg_last_xact_replay_timestamp() AS slave_time_delay
)
SELECT * FROM pg_lag;
