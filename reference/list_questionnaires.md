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
#>           key                                              name n_items
#> 1  acceptance                     Van der Laan acceptance scale       9
#> 2  attrakdiff                                      AttrakDiff 2      28
#> 3         fms                  Fast Motion Sickness Scale (FMS)       1
#> 4         ipq               igroup Presence Questionnaire (IPQ)      14
#> 5        misc                               Misery Scale (MISC)       1
#> 6    nasa_tlx                  NASA Task Load Index, raw (RTLX)       6
#> 7         ssq            Simulator Sickness Questionnaire (SSQ)      16
#> 8         sus                      System Usability Scale (SUS)      10
#> 9         tia                         Trust in Automation (TiA)      19
#> 10        ueq    User Experience Questionnaire (UEQ), full form      26
#> 11      ueq_s User Experience Questionnaire, short form (UEQ-S)       8
#>    n_subscales scale     higher_is
#> 1            2  -2-2        better
#> 2            4   1-7        better
#> 3            1  0-20         worse
#> 4            4   0-6 more presence
#> 5            1  0-10         worse
#> 6            6 0-100         worse
#> 7            3   0-3         worse
#> 8            2   1-5        better
#> 9            6   1-5        better
#> 10           6   1-7        better
#> 11           2   1-7        better
#>                                                                                            reference
#> 1                                         Van der Laan, Heino & De Waard (1997), Transp. Res. C 5(1)
#> 2                                      Hassenzahl, Burmester & Koller (2003), Mensch & Computer 2003
#> 3                                                      Keshavarz & Hecht (2011), Human Factors 53(4)
#> 4                               Schubert, Friedmann & Regenbrecht (2001), Presence 10(3); igroup.org
#> 5  Wertheim, Bos & Bles (1998); Bos, MacKinnon & Patterson (2005), Aviat. Space Environ. Med. 76(12)
#> 6                                  Hart & Staveland (1988), Adv. Psychology 52; Hart (2006), HFES 50
#> 7                       Kennedy, Lane, Berbaum & Lilienthal (1993), Int. J. Aviation Psychology 3(3)
#> 8                        Brooke (1996), Usability Evaluation in Industry; Lewis & Sauro (2009), HCII
#> 9                  Koerber (2018), Proc. IEA 2018, Advances in Intelligent Systems and Computing 823
#> 10                                      Laugwitz, Held & Schrepp (2008), USAB; Schrepp, UEQ Handbook
#> 11                                             Schrepp, Hinderks & Thomaschewski (2017), IJIMAI 4(6)
```
