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
