-- 
-- packages/intranet-collmex/sql/postgresql/intranet-collmex-create.sql
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
-- @creation-date 2012-01-06
-- @cvs-id $Id$
--

SELECT acs_log__debug('/packages/intranet-collmex/sql/postgresql/intranet-collmex-create.sql','');

alter table im_companies add column collmex_id integer;
update im_offices set address_country_code = 'de' where address_country_code is null

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS integer AS '
DECLARE
	v_attribute_id		integer;
	v_count			integer;
	row			record;
BEGIN

	v_attribute_id := im_dynfield_attribute_new (''im_company'', ''collmex_id'', ''Collmex ID'', ''integer'', ''integer'', ''f'');

	FOR row IN 
		SELECT category_id FROM im_categories WHERE category_id NOT IN (100,101) AND category_type = ''Intranet Company Type''
	LOOP
			
		SELECT count(*) INTO v_count FROM im_dynfield_type_attribute_map WHERE attribute_id = v_attribute_id AND object_type_id = row.category_id;
		IF v_count = 0 THEN
		   INSERT INTO im_dynfield_type_attribute_map
		   	  (attribute_id, object_type_id, display_mode, help_text,section_heading,default_value,required_p)
		   VALUES
			  (v_attribute_id, row.category_id,''display'',null,null,null,''f'');
		ELSE
		   UPDATE im_dynfield_type_attribute_map SET display_mode = ''display'', required_p = ''f'' WHERE attribute_id = v_attribute_id AND object_type_id = row.category_id;
		END IF;

	END LOOP;


	RETURN 0;

END;' language 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();

alter table im_payments add column collmex_id varchar(20);


-- Add Collmex Kostenstelle
CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS integer AS '
DECLARE
	v_acs_attribute_id	integer;
	v_attribute_id		integer;
	v_count			integer;
	row			record;
BEGIN


	SELECT attribute_id INTO v_acs_attribute_id FROM acs_attributes WHERE object_type = ''im_cost_center'' AND attribute_name = ''collmex_kostenstelle'';
	
	IF v_acs_attribute_id IS NOT NULL THEN
	   v_attribute_id := im_dynfield_attribute__new_only_dynfield (
	       null,					-- attribute_id
	       ''im_dynfield_attribute'',		-- object_type
	       now(),					-- creation_date
	       null,					-- creation_user
	       null,					-- creation_ip
	       null,					-- context_id	
	       v_acs_attribute_id,			-- acs_attribute_id
	       ''textbox_medium'',			-- widget
	       ''f'',					-- deprecated_p
	       ''t'',					-- already_existed_p
	       null,					-- pos_y
	       ''plain'',				-- label_style
	       ''f'',					-- also_hard_coded_p   
	       ''t''					-- include_in_search_p
	  );
	ELSE
	  v_attribute_id := im_dynfield_attribute_new (
	  	 ''im_cost_center'',			-- object_type
		 ''collmex_kostenstelle'',			-- column_name
		 ''#intranet-collmex.Kostenstelle#'',	-- pretty_name
		 ''textbox_medium'',			-- widget_name
		 ''string'',				-- acs_datatype
		 ''f'',					-- required_p   
		 1,					-- pos y
		 ''f'',					-- also_hard_coded
		 ''im_cost_centers''			-- table_name
	  );

	END IF;

	RETURN 0;
END;' language 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();