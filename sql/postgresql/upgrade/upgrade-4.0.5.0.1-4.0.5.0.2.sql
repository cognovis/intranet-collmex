-- 
-- packages/intranet-collmex/sql/postgresql/upgrade/upgrade-4.0.5.0.1-4.0.5.0.2.sql
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

SELECT acs_log__debug('/packages/intranet-collmex/sql/postgresql/upgrade/upgrade-4.0.5.0.1-4.0.5.0.2.sql','');

-- Remove Collmex Kostenstelle
CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS integer AS '
DECLARE
	v_acs_attribute_id  integer;
	v_attribute_id      integer;
BEGIN


	SELECT attribute_id INTO v_acs_attribute_id FROM acs_attributes WHERE object_type = ''im_cost_center'' AND attribute_name = ''collmex_kostenstelle'';
	IF v_acs_attribute_id IS NOT NULL THEN
       SELECT attribute_id INTO v_attribute_id FROM im_dynfield_attributes WHERE acs_attribute_id = v_acs_attribute_id;
       
       IF v_attribute_id IS NOT NULL THEN
           
           -- Copy the cost center
           UPDATE im_cost_centers SET note = cost_center_code;
           UPDATE im_cost_centers SET cost_center_code = collmex_kostenstelle WHERE collmex_kostenstelle IS NOT NULL;

           DELETE FROM im_dynfield_type_attribute_map WHERE attribute_id = v_attribute_id;
           PERFORM im_dynfield_attribute__del(v_attribute_id);
       ELSE
           PERFORM acs_attribute__drop_attribute(''im_cost_centers'', ''collmex_kostenstelle'');
       END IF;
    END IF;
	RETURN 0;
END;' language 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

-- Add the categories for the default payment days
create or replace function inline_0 ()
returns integer as $body$
declare
        v_category_id   integer;
begin
SELECT category_id into v_category_id from im_categories where category_type = 'Intranet Payment Term' limit 1;
IF v_category_id IS NULL THEN
    -- Create the collmex categories
    perform im_category_new (80130, '30 days', 'Intranet Payment Term');
    update im_categories set aux_int1 = 30, aux_int2=0 where category_id = 80130;
    perform im_category_new (80160, '60 days', 'Intranet Payment Term');
    update im_categories set aux_int1 = 60, aux_int2=8 where category_id = 80160;
    perform im_category_new (80114, '14 days', 'Intranet Payment Term');
    update im_categories set aux_int1 = 14, aux_int2=6 where category_id = 80114;
    perform im_category_new (80114, '0 days', 'Intranet Payment Term');
    update im_categories set aux_int1 = 0, aux_int2=1, aux_string1='immediately' where category_id = 80100;
ELSE
    update im_categories set aux_int1 = 0, aux_int2=1, aux_string1='immediately' where category_type = 'Intranet Payment Term' and aux_int1 = 0;
    update im_categories set aux_int1 = 30, aux_int2=1, aux_string1='within 30 days' where category_type = 'Intranet Payment Term' and aux_int1 = 30;
    update im_categories set aux_int1 = 60, aux_int2=1, aux_string1='within 60 days' where category_type = 'Intranet Payment Term' and aux_int1 = 60;
    update im_categories set aux_int1 = 14, aux_int2=1, aux_string1='within 14 days' where category_type = 'Intranet Payment Term' and aux_int1 = 14;
END IF;
RETURN 0;
end;$body$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();