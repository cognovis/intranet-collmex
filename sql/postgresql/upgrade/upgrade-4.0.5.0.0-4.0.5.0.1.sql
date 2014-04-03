-- 
-- packages/intranet-collmex/sql/postgresql/upgrade/upgrade-4.0.5.0.0-4.0.5.0.1.sql
-- 
-- Copyright (c) 2011, cognovís GmbH, Hamburg, Germany
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
-- 
-- @author <yourname> (<your email>)
-- @creation-date 2012-01-27
-- @cvs-id $Id$
--

SELECT acs_log__debug('/packages/intranet-collmex/sql/postgresql/upgrade/upgrade-4.0.5.0.0-4.0.5.0.1.sql','');

-- Add CollmexID to users_contact 
 
create or replace function inline_0 ()
returns integer as $body$
declare
    v_count  integer;
begin
    -- Drop the old unique constraints
    select count(*) into v_count from user_tab_columns
    where lower(table_name) = 'users_contact' and lower(column_name) = 'collmex_id';
    IF v_count > 0 THEN
        return 1;
    END IF;
 
    alter table users_contact
    add column collmex_id integer unique;
 
    return 0;
end;$body$ language 'plpgsql';
select inline_0();
drop function inline_0();