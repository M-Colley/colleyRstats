# Cleaning and scoring.
#
# Every exclusion and recoding decision belongs here, one visible line each, so
# that a co-author or reviewer can read what was done to the data without
# reading the whole analysis.

prepare_study <- function(data) {
  data <- dplyr::mutate(
    data,
    participant = factor(participant),
    # Setting the level order here fixes it everywhere downstream: the model's
    # reference level, the order of the post-hoc contrasts, and the order the
    # groups appear along the x-axis of every figure.
    condition = factor(condition, levels = c("baseline", "ambient", "explicit"))
  )

  # Exclusions go here, each with the reason in the comment, e.g.
  #   data <- dplyr::filter(data, participant != "07")  # aborted, simulator sickness

  # Questionnaire items must be numbers. score_questionnaire() stops on an item
  # column holding text ("Strongly agree", "5 - Strongly agree", "2,5") rather
  # than silently turning those answers into missing values, and names the
  # offending values. Recode such columns here, visibly, e.g.
  #   labels <- c("Strongly disagree" = 1, "Disagree" = 2, "Neutral" = 3,
  #               "Agree" = 4, "Strongly agree" = 5)
  #   data <- dplyr::mutate(data, dplyr::across(dplyr::starts_with("sus_"),
  #                                             ~ unname(labels[.x])))
  # or, for "5 - Strongly agree", keep the leading number:
  #   data <- dplyr::mutate(data, dplyr::across(dplyr::starts_with("sus_"),
  #     ~ as.numeric(sub("^[[:space:]]*(-?[0-9]+).*$", "\\1", .x))))

  data
}


score_scales <- function(data) {
  # Run check_questionnaire() once per instrument, per study, and read the
  # mapping it prints. Item order and polarity belong to the sheet your
  # participants actually saw: a shifted export scores silently and wrongly.

{{scoring}}
  data
}
