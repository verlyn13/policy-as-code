package charter.article_ii.capital_test

test_allow_personal_with_12_months {
  data.charter.article_ii.capital.allow with input as {
    "entity": {"type": "personal"},
    "financial": {"months_cash_reserve": 12}
  }
}

test_deny_business_with_3_months {
  not data.charter.article_ii.capital.allow with input as {
    "entity": {"type": "litecky_editing"},
    "financial": {"months_cash_reserve": 3}
  }
}
