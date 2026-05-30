# Data-frame column names referenced via non-standard evaluation (dplyr verbs
# and base subset()). Kept intentionally minimal: only symbols that R's own
# codetools flags as unbound globals are declared here, so the list cannot
# silently mask a genuine typo or a misused base-function name.
utils::globalVariables(c(
  "p.value", "p-adjusted", "group1", "group2", "asterisk_label"
))
