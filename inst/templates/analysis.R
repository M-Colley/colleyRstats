# Models.
#
# One entry per dependent variable. fit_recommended() inspects each outcome --
# its measurement scale, whether the design is clustered, whether the parametric
# assumptions hold -- picks the matching model, fits it, computes the post-hoc
# contrasts, and produces the sentence that goes into the manuscript. The test
# you justify in the methods section and the model you actually ran therefore
# come from the same call.

# The dependent variables to analyse. Scored scales plus whatever behavioural
# measures the study logged.
OUTCOMES <- c(
{{outcomes}}
)

# How each outcome should be modelled. This is not redundant with the data: an
# outcome whose scores stay whole numbers -- a single MISC rating, a summed
# Likert scale -- would otherwise be taken for a count and fitted with a count
# model. (Raw NASA-TLX subscales on 0-100, in steps of 5, are recognised as
# continuous, but stating it costs nothing.) A summed or averaged scale is analysed as continuous; a single Likert
# item is "ordinal". Delete an entry to let the data decide, or add one for a
# behavioural measure that needs it.
OUTCOME_TYPES <- c(
{{outcome_types}}
)

# The experimental factor(s), and the column identifying the participant. With
# a within-subjects design the cluster is what turns the analysis into a mixed
# model; set it to NULL for a between-subjects study.
PREDICTORS <- "condition"
CLUSTER <- "participant"


run_models <- function(data) {
  outcomes <- intersect(OUTCOMES, names(data))
  missing <- setdiff(OUTCOMES, outcomes)
  if (length(missing) > 0) {
    warning("Not in the scored data, skipped: ", paste(missing, collapse = ", "))
  }

  fits <- lapply(outcomes, function(dv) {
    fit_recommended(
      data,
      outcome = dv,
      predictors = PREDICTORS,
      cluster = CLUSTER,
      outcome_type = if (dv %in% names(OUTCOME_TYPES)) OUTCOME_TYPES[[dv]] else "auto",
      verbose = FALSE
    )
  })
  names(fits) <- outcomes

  # One row per outcome: what was run, and what it found. This is the table to
  # read first after tar_make(), and the skeleton of the results section.
  summary_table <- do.call(rbind, lapply(outcomes, function(dv) {
    data.frame(
      outcome = dv,
      model = fits[[dv]]$recommendation$recommendation,
      outcome_type = fits[[dv]]$recommendation$outcome_type,
      stringsAsFactors = FALSE
    )
  }))

  list(fits = fits, summary = summary_table)
}


# Descriptives use the observations that the model actually analyzed. Response
# categories are counted rather than coerced to numbers or averaged.
describe_outcome <- function(fit, dv) {
  data <- fit$data
  categorical <- fit$recommendation$outcome_type %in% c("ordinal", "binary", "nominal")
  if (!isTRUE(categorical) && is.numeric(data[[dv]])) {
    return(suppressMessages(report_mean_sd(data, dv = dv, iv = PREDICTORS[[1]])))
  }
  counts <- table(droplevels(as.factor(data[[PREDICTORS[[1]]]])), data[[dv]])
  vapply(seq_len(nrow(counts)), function(i) {
    observed <- counts[i, ] > 0
    responses <- paste0(latex_escape(colnames(counts)[observed]),
                        " ($n = ", counts[i, observed], "$")
    paste0(latex_escape(dv), " for ", latex_escape(PREDICTORS[[1]]), " ",
           latex_escape(rownames(counts)[i]), ": ", paste0(responses, ")", collapse = ", "), ".")
  }, character(1))
}


write_manuscript_tex <- function(results, dir = "paper/generated") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  paths <- character(0)

  for (dv in names(results$fits)) {
    path <- file.path(dir, paste0(gsub("[^A-Za-z0-9]+", "-", dv), ".tex"))
    writeLines(results$fits[[dv]]$sentences, path)
    paths <- c(paths, path)
  }

  # Descriptives for the results section, as one \input{}-able file.
  desc <- file.path(dir, "descriptives.tex")
  writeLines(
    unlist(lapply(names(results$fits), function(dv) {
      c(
        paste0("% ", dv),
        describe_outcome(results$fits[[dv]], dv)
      )
    })),
    desc
  )

  c(paths, desc)
}
