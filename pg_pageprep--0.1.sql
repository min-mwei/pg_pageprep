create table pg_pageprep_jobs (
	rel			regclass,			/* relation */
	fillfactor	integer,			/* original fillfactor value */
	status		text,				/* 'done' means done */
	updated		integer
) with (fillfactor=90);
create unique index pg_pageprep_data_idx on pg_pageprep_jobs (rel);

create or replace function pg_pageprep_event_trigger()
returns event_trigger as
$$
begin
    delete from @extschema@.pg_pageprep_jobs
    where rel in (
        select objid
        from pg_event_trigger_dropped_objects()
        where classid = 'pg_class'::regclass
    );
end
$$
language plpgsql;

create event trigger
pg_pageprep_event_trigger
on sql_drop
execute procedure pg_pageprep_event_trigger();

create or replace function scan_pages(
	rel			regclass
)
returns void as 'MODULE_PATHNAME', 'scan_pages_pl'
language c strict;


create or replace function start_bgworker(wait boolean default false)
returns void as 'MODULE_PATHNAME', 'start_bgworker'
language c strict;


create or replace function stop_bgworker()
returns void as 'MODULE_PATHNAME', 'stop_bgworker'
language c strict;


create or replace function estimate_time()
returns bigint as 'MODULE_PATHNAME', 'estimate_time'
language c strict;


create or replace function get_workers_list()
returns table (pid integer, database text, status text)
as 'MODULE_PATHNAME', 'get_workers_list'
language c strict;


create view pg_pageprep_todo as (
	select c.oid, c.relname, p.status
	from pg_class c
	left join @extschema@.pg_pageprep_jobs p on p.rel = c.oid
	where
		relkind in ('r', 't', 'm') and
		relname != 'pg_pageprep_jobs' and
		relpersistence != 't' and
		c.oid >= 16384 and
		(status IS NULL OR status != 'done')
	order by c.relname
);

create or replace function __add_job(rel regclass, fillfactor integer)
returns void as
$$
	insert into @extschema@.pg_pageprep_jobs
	values (rel, fillfactor, 'new')
	on conflict (rel) do nothing;
$$
language sql;


create or replace function __update_fillfactor(relid oid, fillfactor integer)
returns void
as
$$
declare
    row      record;
    relopts  text[];
    relopt   text;
    new_relopts text[];
    found    bool := false;
    fillfactor_str text := format('fillfactor=%s', fillfactor);
begin
    for relopts in select reloptions from pg_class where oid = relid for update
    loop
        for relopt in select * from unnest(relopts)
        loop
            if position('fillfactor' in relopt) > 0 then
                new_relopts := new_relopts || fillfactor_str;
                found := true;
            else
                new_relopts := new_relopts || relopt;
            end if;
        end loop;
    end loop;

    if not found then
        new_relopts := new_relopts || fillfactor_str;
    end if;

    update pg_class set reloptions = new_relopts where oid = relid;
end
$$
language plpgsql;


create or replace function restore_fillfactors()
returns void as
$$
declare
	row record;
begin
	for row in (select rel, fillfactor
				from @extschema@.pg_pageprep_jobs p
				join pg_class c on c.oid = p.rel and c.relkind != 't')
	loop
		perform __update_fillfactor(row.rel, row.fillfactor);
	end loop;
end
$$
language plpgsql;
