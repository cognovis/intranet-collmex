ad_page_contract {
    Purpose: Loads Payments for invoices

    @param return_url the url to return to
    @author malte.sussdorff@cognovis.de
} {
    invoice_id
    return_url
}

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_payments]} {
    ad_return_complaint 1 "<li>[_ intranet-payments.lt_You_have_insufficient]"
    return
}

intranet_collmex::invoice_payment_get -invoice_id $invoice_id -all

ad_returnredirect $return_url
