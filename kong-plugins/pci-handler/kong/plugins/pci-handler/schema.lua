return {
  no_consumer = true,
  fields = {
    card_number_field = {required = true, type = "string"},
    card_expiry_month_field = {required = true, type = "string"},
    card_expiry_year_field = {required = true, type = "string"},
    card_cvv_field = {required = true, type = "string"},
    tokenizer_url = {required = true, type = "string"},
    card_token_output_field = {required = true, type = "string"},
  }
}
