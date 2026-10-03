# List the questionnaires this package can score

List the questionnaires this package can score

## Usage

``` r
list_questionnaires()
```

## Value

A data frame with one row per instrument: its key (the value to pass as
`instrument`), full name, number of items, number of subscales, the
response range it assumes, the direction a high score means, and its
reference.

## See also

[`questionnaire_items()`](https://m-colley.github.io/colleyRstats/reference/questionnaire_items.md),
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md),
[`define_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/define_questionnaire.md)

## Examples

``` r
list_questionnaires()
#>                    key                                              name
#> 1           acceptance                     Van der Laan acceptance scale
#> 2           attrakdiff                                      AttrakDiff 2
#> 3  attrakdiff_official     AttrakDiff 2 (official sheet order and poles)
#> 4                  fms                  Fast Motion Sickness Scale (FMS)
#> 5                  ipq               igroup Presence Questionnaire (IPQ)
#> 6                 misc                               Misery Scale (MISC)
#> 7             nasa_tlx                  NASA Task Load Index, raw (RTLX)
#> 8                  ssq            Simulator Sickness Questionnaire (SSQ)
#> 9                  sus                      System Usability Scale (SUS)
#> 10                 tia                         Trust in Automation (TiA)
#> 11                 ueq    User Experience Questionnaire (UEQ), full form
#> 12               ueq_s User Experience Questionnaire, short form (UEQ-S)
#>    n_items n_subscales scale     higher_is
#> 1        9           2  -2-2        better
#> 2       28           4   1-7        better
#> 3       28           4   1-7        better
#> 4        1           1  0-20         worse
#> 5       14           4   0-6 more presence
#> 6        1           1  0-10         worse
#> 7        6           6 0-100         worse
#> 8       16           3   0-3         worse
#> 9       10           2   1-5        better
#> 10      19           6   1-5        better
#> 11      26           6   1-7        better
#> 12       8           2   1-7        better
#>                                                                                                                                                      reference
#> 1                                                                                                   Van der Laan, Heino & De Waard (1997), Transp. Res. C 5(1)
#> 2                                                                                                Hassenzahl, Burmester & Koller (2003), Mensch & Computer 2003
#> 3  Hassenzahl, Burmester & Koller (2003), Mensch & Computer 2003; order and poles as administered (cf. Lallemand et al., 2015, Eur. Rev. Appl. Psychol. 65(5))
#> 4                                                                                                                Keshavarz & Hecht (2011), Human Factors 53(4)
#> 5                                                                                         Schubert, Friedmann & Regenbrecht (2001), Presence 10(3); igroup.org
#> 6                                                            Wertheim, Bos & Bles (1998); Bos, MacKinnon & Patterson (2005), Aviat. Space Environ. Med. 76(12)
#> 7                                                                                            Hart & Staveland (1988), Adv. Psychology 52; Hart (2006), HFES 50
#> 8                                                                                 Kennedy, Lane, Berbaum & Lilienthal (1993), Int. J. Aviation Psychology 3(3)
#> 9                                                                                  Brooke (1996), Usability Evaluation in Industry; Lewis & Sauro (2009), HCII
#> 10                                                                           Koerber (2019), Proc. IEA 2018, Advances in Intelligent Systems and Computing 823
#> 11                                                                                                Laugwitz, Held & Schrepp (2008), USAB; Schrepp, UEQ Handbook
#> 12                                                                                                       Schrepp, Hinderks & Thomaschewski (2017), IJIMAI 4(6)
```
