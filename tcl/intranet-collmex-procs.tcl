# packages/intranet-collmex/tcl/intranet-collmex-procs.tcl

## Copyright (c) 2011, cognovís GmbH, Hamburg, Germany
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
# 

ad_library {
    
    Procedure to interact with collmex
    
    @author <yourname> (<your email>)
    @creation-date 2012-01-04
    @cvs-id $Id$
}

namespace eval intranet_collmex {}
package require tls

ad_proc -public intranet_collmex::http_post {
    {-csv_data ""}
} {
} {
    # Make sure we can use HTTPS
    ::http::register https 443 ::tls::socket

    set customer_nr [parameter::get_from_package_key -package_key intranet-collmex -parameter CollmexKundenNr]
    set login [parameter::get_from_package_key -package_key intranet-collmex -parameter Login]
    set password  [parameter::get_from_package_key -package_key intranet-collmex -parameter Password]
    set active_p [parameter::get_from_package_key -package_key intranet-collmex -parameter ActiveP]

    set data "LOGIN;$login;$password\n${csv_data}\n"


    # Handle errors in the http connection    
    set error_p [catch {set token [::http::geturl https://www.collmex.de/cgi-bin/cgi.exe?${customer_nr},0,data_exchange \
				       -type "text/csv" \
				       -query $data]} errmsg]
    if {[::http::ncode $token] ne "200"} {
	set error_p 1
	set errmsg [::http::code $token]
    }

    if {$active_p} {
        set response [::http::data $token]
	ns_log Notice "Collmex Query: $data"
        ns_log Notice "Collmex:: $response"

        set meldungstyp [lindex [split $response ";"] 1]

	# Make sure even an http error is treated as a regular error.
	if {$error_p} {
	    set meldungstype "E"
	    set response $errmsg
	}

        switch $meldungstyp {
            S {
                return $response
            }
            W {
                # Warning Mail
                acs_mail_lite::send -send_immediately -to_addr [ad_admin_owner] -from_addr [ad_admin_owner] -subject "Collmex Warning" -body "There was a warning in collmex, but the call was successful. <p /> \
                <br />Called: $csv_data \
                <br />Reponse $response" -mime_type "text/html"
                return $response
            }
	    E {
		if {[string match "INVOICE_PAYMENT_GET*" $csv_data]} {
		    # It is not a critical issue if we can't get the payments, therefore we only
		    # log the issue as a notice
		    ns_log Notice "Error in Collmex: $response when calling $csv_data"
		} else {
		    # Error Mail
	            ns_log Error "Error in Collmex: $response"
	            acs_mail_lite::send -send_immediately -to_addr [ad_admin_owner] -from_addr [ad_admin_owner] -subject "Collmex Error" -body "There was a error in collmex, data is not transferred.<p /> \
                <br />Called: $csv_data \
                <br />Reponse $response" -mime_type "text/html"
		    return "-1"
		}
            }
            default {
                return $response
            }
        }
    }
}

ad_proc -public intranet_collmex::update_company {
    -company_id
    -customer:boolean
} {
    send the company to collmex for update

    use field description from http://www.collmex.de/cgi-bin/cgi.exe?1005,1,help,daten_importieren_kunde
} {
    
    if {$customer_p} {
	set Satzart "CMXKND"
    } else {
	set Satzart "CMXLIF"
    }

    set bank_account_nr ""
    set bank_routing_nr ""
    set iban ""
    set bic ""
    set bank_name ""
    set tax_number ""
    set vat_number ""
    db_1row customer_info {
	select *
        from im_offices o, im_companies c
	left outer join (select * from persons p, parties pa where p.person_id = pa.party_id) po  
	   on c.primary_contact_id = po.person_id 
	where c.main_office_id = o.office_id
	and c.company_id = :company_id
    } 

    # Translation of the country code
    switch $address_country_code {
	"uk" {set address_country_code gb}
	""   {set address_country_code de} ; # default country code germany
    }

    if {$email eq "" && $address_city eq ""} {
	acs_mail_lite::send -send_immediately -to_addr [ad_admin_owner] -from_addr [ad_admin_owner] -subject "Company without email" \
	    -body "Company $company_name has no E-Mail or Address, can't create"
	return 0
	ad_script_abort
    }

    set csv_line "$Satzart"
    
    if {[exists_and_not_null collmex_id]} {
	append csv_line ";$collmex_id"
    } else {
	append csv_line ";"
    }
    
    append csv_line ";1" ; # Firma Nr (internal)
    append csv_line ";" ; # Anrede
    append csv_line ";" ; # Title
    append csv_line ";\"[im_csv_duplicate_double_quotes $first_names]\"" ; # Vorname
    append csv_line ";\"[im_csv_duplicate_double_quotes $last_name]\"" ;# Name
    append csv_line ";\"[im_csv_duplicate_double_quotes $company_name]\"" ; # Firma
    append csv_line ";\"[im_csv_duplicate_double_quotes $title]\"" ; # Abteilung
    
    append address_line1 "\n $address_line2"
    append csv_line ";\"[im_csv_duplicate_double_quotes $address_line1]\"" ; # Straße
    
    append csv_line ";\"[im_csv_duplicate_double_quotes $address_postal_code]\"" ; # PLZ
    append csv_line ";\"[im_csv_duplicate_double_quotes $address_city]\"" ; # Ort
    append csv_line ";\"[im_csv_duplicate_double_quotes $note]\"" ; # Bemerkung
    append csv_line ";0" ; # Inaktiv
    append csv_line ";\"[im_csv_duplicate_double_quotes $address_country_code]\"" ; # Land
    append csv_line ";\"[im_csv_duplicate_double_quotes $phone]\"" ; # Telefon
    append csv_line ";\"[im_csv_duplicate_double_quotes $fax]\"" ; # Telefax
    append csv_line ";\"[im_csv_duplicate_double_quotes $email]\"" ; # E-Mail
    append csv_line ";\"[im_csv_duplicate_double_quotes $bank_account_nr]\"" ; # Kontonr
    append csv_line ";\"[im_csv_duplicate_double_quotes $bank_routing_nr]\"" ; # Blz
    append csv_line ";\"[im_csv_duplicate_double_quotes $iban]\"" ; # Iban
    append csv_line ";\"[im_csv_duplicate_double_quotes $bic]\"" ; # Bic
    append csv_line ";\"[im_csv_duplicate_double_quotes $bank_name]\"" ; # Bankname
    append csv_line ";\"[im_csv_duplicate_double_quotes $tax_number]\"" ; # Steuernummer
    append csv_line ";\"[im_csv_duplicate_double_quotes $vat_number]\"" ; # USt.IdNr
    append csv_line ";6" ; # Zahlungsbedingung
    
    if {$customer_p} {
	append csv_line ";" ; # Rabattgruppe
    }
    
    append csv_line ";" ; # Lieferbedingung
    append csv_line ";" ; # Lieferbedingung Zusatz
    append csv_line ";1" ; # Ausgabemedium
    append csv_line ";" ; # Kontoinhaber
    append csv_line ";" ; # Adressgruppe
    
    if {$customer_p} {
	append csv_line ";" ; # eBay-Mitgliedsname
	append csv_line ";" ; # Preisgruppe
	append csv_line ";" ; # Währung (ISO-Codes)
	append csv_line ";" ; # Vermittler
	append csv_line ";" ; # Kostenstelle
	append csv_line ";" ; # Wiedervorlage am
	append csv_line ";" ; # Liefersperre
	append csv_line ";" ; # Baudienstleister
	append csv_line ";" ; # Lief-Nr. bei Kunde
	append csv_line ";" ; # Ausgabesprache
	append csv_line ";" ; # CC
	append csv_line ";" ; # Telefon2
    } else {
	append csv_line ";" ; # Kundennummer beim Lieferanten
	append csv_line ";" ; # Währung (ISO-Codes)
	append csv_line ";" ; # Telefon2
	append csv_line ";" ; # Ausgabesprache
    }
    
    set response [intranet_collmex::http_post -csv_data $csv_line]
    if {$response != "-1"} {
	set response [split $response ";"]
	if {[lindex $response 0] == "NEW_OBJECT_ID"} {
	    ns_log Notice "New Customer:: [lindex $response 1]"
	    # This seems to be a new customer
	    if {$collmex_id eq ""} {
		db_dml update_collmex_id "update im_companies set collmex_id = [lindex $response 1] where company_id = :company_id"
		set return_message [lindex $response 1]
	    } else {
		set return_message "Problem: Collmex ID exists for new company $company_id :: $collmex_id :: new [lindex $response 1]"
		acs_mail_lite::send -send_immediately -to_addr [ad_admin_owner] -from_addr [ad_admin_owner] -subject "Collmex ID already present in project-open" -body "$return_message"
	    }
	}
    }
}

ad_proc -public intranet_collmex::update_provider_bill {
    -invoice_id
    -storno:boolean
} {
    send the provider bill to collmex
} {
    # Get all the invoice information
    db_1row invoice_data {
	select collmex_id,to_char(effective_date,'YYYYMMDD') as invoice_date, invoice_nr, 
	round(vat,0) as vat, round(amount,2) as netto, c.company_id, address_country_code, ca.aux_int2 as konto, cc.cost_center_code as kostenstelle
	from im_invoices i, im_costs ci, im_companies c, im_offices o, im_categories ca, im_cost_centers cc
	where c.company_id = ci.provider_id 
	and c.main_office_id = o.office_id
	and ci.cost_id = i.invoice_id 
	and ca.category_id = c.vat_type_id
        and cc.cost_center_id = ci.cost_center_id
	and i.invoice_id = :invoice_id
    }

    regsub -all {\.} $netto {,} netto

    set csv_line "CMXLRN"

    if {$collmex_id eq ""} {
	set collmex_id [intranet_collmex::update_company -company_id $company_id]
    }

    append csv_line ";$collmex_id" ; # Lieferantennummer
    append csv_line ";1" ; # Firma Nr
    append csv_line ";$invoice_date" ; # Rechnungsdatum
    append csv_line ";$invoice_nr" ; # Rechnungsnummer

    if {$konto eq ""} {
	set konto [parameter::get_from_package_key -package_key "intranet-collmex" -parameter "KontoBill"]
    }

    # Find if the provide is from germany and has vat.
    if {$vat eq 19} {
	append csv_line ";\"[im_csv_duplicate_double_quotes $netto]\"" ; # Nettobetrag voller Umsatzsteuersatz
    } else {
	append csv_line ";"
    }
    append csv_line ";" ; # Steuer zum vollen Umsatzsteuersatz
    append csv_line ";" ; # Nettobetrag halber Umsatzsteuersatz
    append csv_line ";" ; # Steuer zum halben Umsatzsteuersatz
    if {$vat eq 19} {
	append csv_line ";"
	append csv_line ";"
    } else {
	append csv_line ";$konto" ; # Sonstige Umsätze: Konto Nr.
	append csv_line ";\"[im_csv_duplicate_double_quotes $netto]\"" ; # Sonstige Umsätze: Betrag
    }

    append csv_line ";\"EUR\"" ; # Währung (ISO-Codes)
    append csv_line ";" ; # Gegenkonto (1600 per default)
    append csv_line ";" ; # Gutschrift
    append csv_line ";" ; # Belegtext
    append csv_line ";6" ; # Zahlungsbedingung
    if {$vat eq 19} {
	append csv_line ";$konto" ; # KontoNr voller Umsatzsteuersatz
    } else {
	append csv_line ";"
    }
    append csv_line ";" ; # KontoNr halber Umsatzsteuersatz
    if {$storno_p} {
	append csv_line ";1" ; # Storno
    } else {
	append csv_line ";" ; # Storno
    }
    append csv_line ";$kostenstelle" ; # Kostenstelle

    set response [intranet_collmex::http_post -csv_data $csv_line]
}

ad_proc -public intranet_collmex::update_customer_invoice {
    -invoice_id
    -storno:boolean
    -line_items:boolean
} {
    send the customer invoice to collmex
    
    @param invoice_id Invoice to be sent over to Collmex
    @param storno Add this flag if you want to storno the invoice
    @param line_items Add this flag if you want to transfer the individual lineitems. This only works with correctly maintained materials in the line items which link back to material groups that have a tax_id
} {
    set corr_invoice_nr ""
    
    # Get all the invoice information
    db_1row invoice_data {
        select collmex_id,to_char(effective_date,'YYYYMMDD') as invoice_date, invoice_nr, cost_type_id,
          round(vat,0) as vat, round(amount,2) as invoice_netto, c.company_id, address_country_code, ca.aux_int1 as customer_vat,
          ca.aux_int2 as customer_konto, cc.cost_center_code as kostenstelle, cb.aux_int2 as collmex_payment_term_id, amount
        from im_invoices i, im_costs ci, im_companies c, im_offices o, im_categories ca, im_cost_centers cc, im_categories cb
        where c.company_id = ci.customer_id 
            and c.main_office_id = o.office_id
            and ci.cost_id = i.invoice_id 
            and cc.cost_center_id = ci.cost_center_id
            and ca.category_id = c.vat_type_id
            and cb.category_id = ci.payment_term_id
            and i.invoice_id = :invoice_id
    }

    if {$collmex_id eq ""} {
        set collmex_id [intranet_collmex::update_company -company_id $company_id -customer]
    }

    # In case we did not get line_items as a boolean, check if the invoice if of vat_type for line items.
    if {$line_items_p == 0} {set line_items_p [db_string line_item_p "select 1 from im_costs where vat_type_id = 42021 and cost_id = :invoice_id" -default 0]}

    # In case this is a correction invoice, get the linked invoice
    if {$cost_type_id == [im_cost_type_correction_invoice]} {
        set linked_invoice_ids [relation::get_objects -object_id_two $invoice_id -rel_type "im_invoice_invoice_rel"]
        if {$linked_invoice_ids ne ""} {
            db_foreach linked_list "select c.amount as linked_amount, cost_type_id as linked_cost_type_id,cost_status_id as linked_cost_status_id, invoice_nr as linked_invoice_nr, coalesce((select sum(p.amount) from im_payments p where p.cost_id = c.cost_id),0) as paid_amount
                from im_costs c, im_invoices i 
                where cost_id in ([template::util::tcl_to_sql_list $linked_invoice_ids])
                and cost_id = invoice_id
            " {
                if {$linked_cost_type_id == [im_cost_type_invoice] && $linked_cost_status_id != [im_cost_status_paid]} {
		           ns_log Notice "Checking for amount for correction invoice $linked_amount :: $amount :: $paid_amount"
        		    # Linked amount = Old Invoice. Old Invoice - Paid amount needs to be higher then the invers
        		    # of the correction invoice. So the remaining "due" is larger or equal to the correction invoice
        		    if {[expr {$linked_amount - $paid_amount}] >= [expr {$amount * -1}]} {
            			# The correction invoice is smaller, therefore we can even it out
            			set corr_invoice_nr $linked_invoice_nr
        		    }
                }
            }
        }
    }
    
    if {$line_items_p} {
	ns_log Notice "Updating Collmex invoice for $invoice_id line items"
        db_1row item_data {select round(sum(item_units*price_per_unit),2) as total_amount, array_to_string(array_agg(item_name), ', ') as items_text 
            from (select item_units,price_per_unit,item_name from im_invoice_items ii where ii.invoice_id = :invoice_id order by sort_order) as items}
        

#        if {$total_amount ne $invoice_netto} {
#            ns_log Error "Invoice amount for $invoice_id not equal sum of line items $total_amount != $invoice_netto"
#            ds_comment "Invoice amount for $invoice_id not equal sum of line items $total_amount != $invoice_netto"
#            return 0
#        }
        set csv_line "" 
        # Transfer one FI line item per invoice line
        db_foreach line_item {
            select sum(round(item_units*price_per_unit,2)) as line_item_netto, ct.aux_int1 as vat, ct.aux_int2 as line_item_konto
            from im_categories cm, im_categories ct, im_invoice_items ii, im_materials im
            where cm.aux_int2 = ct.category_id
            and ii.item_material_id = im.material_id
            and im.material_type_id = cm.category_id
            and ii.invoice_id = :invoice_id 
            group by ct.aux_int1,ct.aux_int2
        } {
            # Override line item vat if the customer is tax free.
            if {$customer_vat eq 0} {
                set vat 0
                set line_item_konto $customer_konto
            }
            
            regsub -all {\.} $line_item_netto {,} netto                        
            regsub -all {\-} $netto {} netto                        

            # Create one FI line item per sales order line item
            if {$csv_line ne ""} {append csv_line "\n"}
            append csv_line "CMXUMS"; # 1
            append csv_line ";$collmex_id" ; # 2 Lieferantennummer
            append csv_line ";1" ; # 3 Firma Nr
            append csv_line ";$invoice_date" ; # 4 Rechnungsdatum
            append csv_line ";$invoice_nr" ; # 5 Rechnungsnummer
            
            if {$vat eq 19} {
                append csv_line ";\"[im_csv_duplicate_double_quotes $netto]\"" ; # 6 Nettobetrag voller Umsatzsteuersatz
            } else {
            	append csv_line ";"
            }
            append csv_line ";" ; # 7 Steuer zum vollen Umsatzsteuersatz
            if {$vat eq 7} {
                append csv_line ";\"[im_csv_duplicate_double_quotes $netto]\"" ;  # 8 Nettobetrag halber Umsatzsteuersatz
            } else {
            	append csv_line ";"
            }
            append csv_line ";" ; # 9 Steuer zum halben Umsatzsteuersatz
            append csv_line ";" ; # 10 Umsätze Innergemeinschaftliche Lieferung
            append csv_line ";" ; # 11 Umsätze Export
            if {$vat eq 0} {
                append csv_line ";$line_item_konto" ; # 12 Steuerfreie Erloese Konto
                append csv_line ";\"[im_csv_duplicate_double_quotes $netto]\""; # Steuerfrei Betrag
            } else {
                append csv_line ";" ; # 12 Hat VAT => Nicht Steuerfrei
                append csv_line ";" ; # 13 Hat VAT => Nicht Steuerfrei
            }
            append csv_line ";\"EUR\"" ; # 14Währung (ISO-Codes)
            append csv_line ";" ; # 15 Gegenkonto
            if {$line_item_netto >=0} {
                append csv_line ";0" ; # 16 Rechnungsart
            } else {
                append csv_line ";1" ; # 16 Rechnungsart Gutschrift
            }
            append csv_line ";\"[im_csv_duplicate_double_quotes $items_text]\"" ; # 17 Belegtext
            append csv_line ";$collmex_payment_term_id" ; # 18 Zahlungsbedingung
            if {$vat eq 19} {
            	append csv_line ";$line_item_konto" ; # 19 KontoNr voller Umsatzsteuersatz
            } else {
            	append csv_line ";" ; # 19 KontoNr voller Umsatzsteuersatz
            }
            if {$vat eq 7} {
            	append csv_line ";$line_item_konto" ; # 20 KontoNr halber Umsatzsteuersatz
            } else {
            	append csv_line ";" ; # 20 KontoNr halber Umsatzsteuersatz
            }
            append csv_line ";" ; # 21 reserviert
            append csv_line ";" ; # 22 reserviert
            if {$storno_p} {
                append csv_line ";1" ; # 23 Storno
            } else {
                append csv_line ";" ; # 23 Storno
            }
            append csv_line ";" ; # 24 Schlussrechnung
            append csv_line ";" ; # 25 Erloesart
            append csv_line ";\"projop\"" ; # 26 Systemname
            append csv_line ";\"$corr_invoice_nr\"" ; # 27 Verrechnen mit Rechnugnsnummer fuer gutschrift
            append csv_line ";\"$kostenstelle\"" ; # 28 Kostenstelle
        }
    
    } else {
	ns_log Notice "Updating Collmex invoice for $invoice_id without line items"

        regsub -all {\.} $invoice_netto {,} netto

        set csv_line "CMXUMS"; # 1
	
        append csv_line ";$collmex_id" ; # 2 Lieferantennummer
        append csv_line ";1" ; # 3 Firma Nr
        append csv_line ";$invoice_date" ; # 4 Rechnungsdatum
        append csv_line ";$invoice_nr" ; # 5 Rechnungsnummer

        if {$customer_konto eq ""} {
            set konto [parameter::get_from_package_key -package_key "intranet-collmex" -parameter "KontoInvoice"]
        }

        # Find if the provide is from germany and has vat.
        if {$vat eq 19} {
            append csv_line ";\"[im_csv_duplicate_double_quotes $netto]\"" ; # 6 Nettobetrag voller Umsatzsteuersatz
        } else {
            append csv_line ";"
        }
    
        append csv_line ";" ; # 7 Steuer zum vollen Umsatzsteuersatz
        append csv_line ";" ; # 8 Nettobetrag halber Umsatzsteuersatz
        append csv_line ";" ; # 9 Steuer zum halben Umsatzsteuersatz
        append csv_line ";" ; # 10 Umsätze Innergemeinschaftliche Lieferung
        append csv_line ";" ; # 11 Umsätze Export
        if {$vat eq 19} {
            append csv_line ";" ; # 12 Hat VAT => Nicht Steuerfrei
            append csv_line ";" ; # 13 Hat VAT => Nicht Steuerfrei
        } else {
            append csv_line ";$customer_konto" ; # 12 Steuerfreie Erloese Konto
            append csv_line ";\"[im_csv_duplicate_double_quotes $netto]\""; # Steuerfrei Betrag
        }
        append csv_line ";\"EUR\"" ; # 14Währung (ISO-Codes)
        append csv_line ";" ; # 15 Gegenkonto
        append csv_line ";0" ; # 16 Rechnungsart
        append csv_line ";" ; # 17 Belegtext
        append csv_line ";$collmex_payment_term_id" ; # 18 Zahlungsbedingung
        if {$vat eq 19} {
            append csv_line ";$customer_konto" ; # 19 KontoNr voller Umsatzsteuersatz
        } else {
            append csv_line ";"
        }
        append csv_line ";" ; # 20 KontoNr halber Umsatzsteuersatz
        append csv_line ";" ; # 21 reserviert
        append csv_line ";" ; # 22 reserviert
        if {$storno_p} {
            append csv_line ";1" ; # 23 Storno
        } else {
            append csv_line ";" ; # 23 Storno
        }
        append csv_line ";" ; # 24 Schlussrechnung
        append csv_line ";" ; # 25 Erloesart
        append csv_line ";\"projop\"" ; # 26 Systemname
        append csv_line ";\"$corr_invoice_nr\"" ; # 27 Verrechnen mit Rechnugnsnummer fuer gutschrift
        append csv_line ";\"$kostenstelle\"" ; # 28 Kostenstelle
    }
    ns_log Notice "$csv_line"
    set response [intranet_collmex::http_post -csv_data $csv_line]    
}
    
ad_proc -public intranet_collmex::invoice_payment_get {
    {-invoice_id ""}
    -all:boolean
} {
    get a list of invoice payments from collmex
} {
    
    set csv_line "INVOICE_PAYMENT_GET;1"
    if {$invoice_id ne ""} {
        set invoice_nr [db_string invoice_nr "select invoice_nr from im_invoices where invoice_id = :invoice_id" -default ""]
        append csv_line ";${invoice_nr}"
    } else {
        append csv_line ";"
    }
    if {$all_p} {
        append csv_line ";"
    } else {
        append csv_line ";1"
    }
    append csv_line ";\"projop\"" ; # Systemname
    
    # Now get the lines from Collmex
    set lines [split [intranet_collmex::http_post -csv_data $csv_line] "\n"]

    ns_log Notice "Returned payments from Collmex: $lines"
    set return_html ""
    foreach line $lines {
        # Find out if it actually is a payment line
        set line_items [split $line ";"]
        if {[lindex $line_items 0] eq "INVOICE_PAYMENT"} {
            set collmex_id  "[lindex $line_items 5]-[lindex $line_items 6]-[lindex $line_items 7]"
            set date  [lindex $line_items 2] ; # Datum
            set amount  [lindex $line_items 4] ; # Actually paid amount
            set invoice_nr [lindex $line_items 1]
            regsub -all {,} $amount {.} amount
            # Check if we have this id already for a payment
            if {[db_string payment_id "select payment_id from im_payments where collmex_id = :collmex_id" -default ""] ne ""} {
                db_dml update "update im_payments set received_date = to_date(:date,'YYYYMMDD'), amount = :amount where collmex_id = :collmex_id"
                append return_html "$invoice_nr <br> $amount :: $collmex_id"
            } else {
                # Find the invoice_id
                set invoice_id [db_string invoice_id "select invoice_id from im_invoices where invoice_nr = :invoice_nr" -default ""]
                if {$invoice_id ne "" && $collmex_id ne "--"} {
		    # Check if we received the payment already
		    set payment_id [db_string payment_id "select payment_id from im_payments where cost_id = :invoice_id and amount = :amount and received_date = to_date(:date,'YYYYMMDD')" -default ""]
		    
		    # Lets record the payment
		    if {$payment_id eq ""} {
			set payment_id [im_payment_create_payment -cost_id $invoice_id -actual_amount $amount]
			db_dml update "update im_payments set received_date = to_date(:date,'YYYYMMDD'), amount = :amount, collmex_id = :collmex_id where payment_id = :payment_id"
		    }
                }
            }
        } 	    
    }
    return 1
}


ad_proc -public intranet_collmex::update_contact {
    -user_id
    -customer:boolean
} {
    send the contact / user to collmex for update

    use field description from http://www.collmex.de/cgi-bin/cgi.exe?1005,1,help,daten_importieren_kunde
} {
    
    if {$customer_p} {
        set Satzart "CMXKND"
    } else {
        set Satzart "CMXLIF"
    }

    db_1row customer_info {
        select *
            from users_contact uc, persons pe, parties pa
            where uc.user_id = pe.person_id
            and pe.person_id = pa.party_id
            and pe.person_id = :user_id
    }

    # Translation of the country code
    switch $ha_country_code {
        "uk" {set ha_country_code gb}
        ""   {set ha_country_code de} ; # default country code germany
    }

    if {$email eq ""} {
        set email "[parameter::get_from_package_key -package_key "acs-kernel" -parameter "HostAdministrator"]"
    }
    
    set csv_line "$Satzart"
    
    if {[exists_and_not_null collmex_id]} {
        append csv_line ";$collmex_id"
    } else {
        append csv_line ";"
    }
    
    append csv_line ";1" ; # Firma Nr (internal)
    append csv_line ";" ; # Anrede
    append csv_line ";" ; # Title
    append csv_line ";\"[im_csv_duplicate_double_quotes $first_names]\"" ; # Vorname
    append csv_line ";\"[im_csv_duplicate_double_quotes $last_name]\"" ;# Name
    append csv_line ";" ; # Firma
    append csv_line ";\"[im_csv_duplicate_double_quotes $title]\"" ; # Abteilung
    
    append ha_line1 "\n $ha_line2"
    append csv_line ";\"[im_csv_duplicate_double_quotes $ha_line1]\"" ; # Straße
    append csv_line ";\"[im_csv_duplicate_double_quotes $ha_postal_code]\"" ; # PLZ
    append csv_line ";\"[im_csv_duplicate_double_quotes $ha_city]\"" ; # Ort
    append csv_line ";\"[im_csv_duplicate_double_quotes $note]\"" ; # Bemerkung
    append csv_line ";0" ; # Inaktiv
    append csv_line ";\"[im_csv_duplicate_double_quotes $ha_country_code]\"" ; # Land
    append csv_line ";\"[im_csv_duplicate_double_quotes $home_phone]\"" ; # Telefon
    append csv_line ";\"[im_csv_duplicate_double_quotes $fax]\"" ; # Telefax
    append csv_line ";\"[im_csv_duplicate_double_quotes $email]\"" ; # E-Mail
    append csv_line ";" ; # Kontonr
    append csv_line ";" ; # Blz
    append csv_line ";" ; # Iban
    append csv_line ";" ; # Bic
    append csv_line ";" ; # Bankname
    append csv_line ";" ; # Steuernummer
    append csv_line ";" ; # USt.IdNr
    append csv_line ";6" ; # Zahlungsbedingung
    
    if {$customer_p} {
        append csv_line ";" ; # Rabattgruppe
    }
    
    append csv_line ";" ; # Lieferbedingung
    append csv_line ";" ; # Lieferbedingung Zusatz
    append csv_line ";1" ; # Ausgabemedium
    append csv_line ";" ; # Kontoinhaber
    append csv_line ";" ; # Adressgruppe
    
    if {$customer_p} {
	    append csv_line ";" ; # eBay-Mitgliedsname
        append csv_line ";" ; # Preisgruppe
        append csv_line ";" ; # Währung (ISO-Codes)
        append csv_line ";" ; # Vermittler
        append csv_line ";" ; # Kostenstelle
        append csv_line ";" ; # Wiedervorlage am
        append csv_line ";" ; # Liefersperre
        append csv_line ";" ; # Baudienstleister
        append csv_line ";" ; # Lief-Nr. bei Kunde
        append csv_line ";" ; # Ausgabesprache
        append csv_line ";" ; # CC
        append csv_line ";" ; # Telefon2
    } else {
        append csv_line ";" ; # Kundennummer beim Lieferanten
        append csv_line ";" ; # Währung (ISO-Codes)
        append csv_line ";" ; # Telefon2
        append csv_line ";" ; # Ausgabesprache
    }
    
    set response [intranet_collmex::http_post -csv_data $csv_line]
    if {$response != "-1"} {
        set response [split $response ";"]
        if {[lindex $response 0] == "NEW_OBJECT_ID"} {
	        ns_log Notice "New Customer:: [lindex $response 1]"
            # This seems to be a new customer
            if {$collmex_id eq ""} {
                db_dml update_collmex_id "update users_contact set collmex_id = [lindex $response 1] where user_id = :user_id"
                set return_message [lindex $response 1]
            } else {
                set return_message "Problem: Collmex ID exists for new contact $user_id :: $collmex_id :: new [lindex $response 1]"
                acs_mail_lite::send -send_immediately -to_addr [ad_admin_owner] -from_addr [ad_admin_owner] -subject "Collmex ID already present in project-open" -body "$return_message"
            }
        }
    }
}
