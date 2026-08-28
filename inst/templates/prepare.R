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

  data
}


score_scales <- function(data) {
  # Run check_questionnaire() once per instrument, per study, and read the
  # mapping it prints. Item order and polarity belong to the sheet your
  # participants actually saw: a shifted export scores silently and wrongly.

{{scoring}}
  data
}
