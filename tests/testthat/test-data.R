test_that("intersections names assembly", {
    expect_equal(
        apply(data.frame(a=c(TRUE, FALSE), b=c(TRUE, TRUE)), 1, names_of_members),
        c('a-b', 'b')
    )

    expect_equal(
        names_of_members(c(a=TRUE, b=TRUE)),
        'a-b'
    )

    sanitazable = c(`a-b`=TRUE, `x-y`=TRUE)
    names(sanitazable) = sanitize_names(names(sanitazable))

    expect_equal(
        names_of_members(sanitazable),
        'a_b-x_y'
    )

    with_conflict = c(`a-b`=TRUE, `a_b`=TRUE)

    expect_error(
        sanitize_names(names(with_conflict)),
        'The group names contain minus characters \\(-\\) which prevent intersections names composition.*'
    )
})


test_that("Intersection degree is properly calculated", {
    # see https://github.com/krassowski/complex-upset/issues/73
    expect_equal(
        calculate_degree(c(
            EMPTY_INTERSECTION, 'a', 'a-b', 'a-b-c'
        )),
        c(
            0, 1, 2, 3
        )
    )
})


test_that("hyphenated variables give the same results", {

    df_underscored = data.frame(
        'a_x'=c(TRUE, FALSE, TRUE, TRUE),
        b=c(TRUE, TRUE, TRUE, TRUE),
        c=c(FALSE, TRUE, FALSE, FALSE),
        d=c(FALSE, FALSE, FALSE, TRUE),
        check.names=FALSE
    )

    df_hyphenated = data.frame(
        'a-x'=c(TRUE, FALSE, TRUE, TRUE),
        b=c(TRUE, TRUE, TRUE, TRUE),
        c=c(FALSE, TRUE, FALSE, FALSE),
        d=c(FALSE, FALSE, FALSE, TRUE),
        check.names=FALSE
    )

    data_underscored = upset_data(df_underscored, c('a_x', 'b', 'c', 'd'))
    data_hyphenated = upset_data(df_hyphenated, c('a-x', 'b', 'c', 'd'))

    expect_equal(
        data_underscored[names(data_underscored) != 'non_sanitized_labels'],
        data_hyphenated[names(data_hyphenated) != 'non_sanitized_labels']
    )

    expect_equal(
        data_hyphenated$non_sanitized_labels,
        c(
            'a_x'='a-x',
            'b'='b',
            'c'='c',
            'd'='d'
        )
    )

    expect_equal(
        data_underscored$non_sanitized_labels,
        c(
            'a_x'='a_x',
            'b'='b',
            'c'='c',
            'd'='d'
        )
    )

})


test_that("sort order parameter verification works", {
    expect_equal(
        check_sort('ascending'),
        TRUE
    )

    expect_equal(
        check_sort('descending'),
        TRUE
    )

    expect_equal(
        check_sort(FALSE),
        TRUE
    )

    expect_error(
        check_sort('abcd'),
        'Sort order has to be one of: descending or ascending, not "abcd"',
        fixed=TRUE
    )
})


test_df = data.frame(
    a=c(TRUE, FALSE),
    b=c(TRUE, TRUE),
    c=c(FALSE, TRUE),
    d=c(FALSE, FALSE),
    # x should be ignored
    x=c(2, 5)
)


expected_intersections_frame = read.table(
    text = (
        "value intersection group
        FALSE          a-b     d
         TRUE          a-b     a
        FALSE          a-b     c
         TRUE          a-b     b
        FALSE          b-c     d
        FALSE          b-c     a
         TRUE          b-c     c
         TRUE          b-c     b"
    ),
    header = TRUE,
    stringsAsFactors = TRUE
)

test_that("upset_data() works", {

    result = upset_data(test_df, c('a', 'b', 'c', 'd'))

    expected_matrix = data.frame(
        `a-b`=c(d=FALSE, a=TRUE, c=FALSE, b=TRUE),
        `b-c`=c(d=FALSE, a=FALSE, c=TRUE, b=TRUE),
        check.names = FALSE
    )

    expect_equal(
        result$matrix,
        expected_matrix
    )

    expect_equal(
        result$matrix_frame,
        expected_intersections_frame
    )
})


test_that("factors are consistently returned by upset_data()", {
    options(stringsAsFactors=F)

    result = upset_data(test_df, c('a', 'b', 'c', 'd'))

    expect_equal(
        result$matrix_frame,
        expected_intersections_frame
    )
})


test_that("upset_data() sorts sets", {
    # Note: the sort order is reversed, as it is reversed by coord_filp in upset_plot;
    # Ideally, it should be corret there and reversed in upset_plot!

    df = data.frame(
        # a - 3 times
        a=c(TRUE, TRUE, TRUE),
        # b - 2 times
        b=c(TRUE, TRUE, FALSE),
        # c - 1 time
        c=c(TRUE, FALSE, FALSE)
    )

    expect_equal(
        upset_data(df, c('a', 'b', 'c'), sort_sets='descending')$sorted$groups,
        c('c', 'b', 'a')
    )

    expect_equal(
        upset_data(df, c('a', 'b', 'c'), sort_sets='ascending')$sorted$groups,
        c('a', 'b', 'c')
    )
})



test_that("upset_data() accepts non logical columns (and warns about conversion)", {
    df = data.frame(
        a=c(1, 0),
        b=c(1, 1),
        c=c(0, 1),
        d=c(0, 0),
        # x should be ignored
        x=c(2, 5)
    )

    expect_warning(
        upset_data(df, c('a', 'b', 'c', 'd', 'x'), warn_when_converting='auto'),
        regexp='Converting non-logical columns to binary: .*'
    )

    expect_warning(
        upset_data(df, c('a', 'b', 'c', 'd'), warn_when_converting='auto'),
        regexp=NA
    )

    expect_warning(
        upset_data(df, c('a', 'b', 'c', 'd'), warn_when_converting=TRUE),
        regexp='Converting non-logical columns to binary: .*'
    )

    expect_warning(
        upset_data(df, c('a', 'b', 'c', 'd'), warn_when_converting=FALSE),
        regexp=NA
    )

    result = upset_data(df, c('a', 'b', 'c', 'd'))

    expected_matrix = data.frame(
        `a-b`=c(d=FALSE, a=TRUE, c=FALSE, b=TRUE),
        `b-c`=c(d=FALSE, a=FALSE, c=TRUE, b=TRUE),
        check.names = FALSE
    )

    expect_equal(
        result$matrix,
        expected_matrix
    )
})

test_that("upset_data() filters by min_size, max_size, min_degree and max_degree", {
    # intersection: size, degree
    # a:     1, 1
    # a-b:   2, 2
    # b-c:   1, 2
    # a-b-d: 1, 3
    # NA:    1, 0
    df = data.frame(
        a=c(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE),
        b=c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
        c=c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE),
        d=c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE)
    )
    empty = 'NOT_IN_EITHER_GROUP'

    old_locale = Sys.getlocale("LC_COLLATE")
    # turn off locale-specific sorting for tests (might not work on some platforms)
    Sys.setlocale("LC_COLLATE", "C")

    result = upset_data(df, c('a', 'b', 'c', 'd'), min_size=2, sort_intersections=FALSE, min_max_early=TRUE)
    expect_equal(result$sorted$intersections, c('a-b'))
    expect_equal(result$plot_intersections_subset, c('a-b'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), min_size=2, sort_intersections=FALSE, min_max_early=FALSE)
    expect_equal(result$sorted$intersections, c(empty, 'a', 'a-b', 'a-b-d', 'b-c'))
    expect_equal(result$plot_intersections_subset, c('a-b'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), max_size=1, sort_intersections=FALSE)
    expect_equal(result$plot_intersections_subset, c(empty, 'a', 'a-b-d', 'b-c'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), max_degree=2, sort_intersections=FALSE)
    expect_equal(result$plot_intersections_subset, c(empty, 'a', 'a-b', 'b-c'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), max_degree=1, sort_intersections=FALSE)
    expect_equal(result$plot_intersections_subset, c(empty, 'a'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), min_degree=2, max_degree=2, sort_intersections=FALSE)
    expect_equal(result$plot_intersections_subset, c('a-b', 'b-c'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), min_degree=2, sort_intersections=FALSE)
    expect_equal(result$plot_intersections_subset, c('a-b', 'a-b-d', 'b-c'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), min_degree=3, sort_intersections=FALSE)
    expect_equal(result$plot_intersections_subset, c('a-b-d'))

    result = upset_data(df, c('a', 'b', 'c', 'd'), n_intersections=1)
    # the largest intersection should be selected
    expect_equal(result$plot_intersections_subset, c('a-b'))

    # restore locale
    Sys.setlocale("LC_COLLATE", old_locale)
})

test_that("upset_data() works with a tibble", {
    # see https://github.com/krassowski/complex-upset/issues/20
    df = data.frame(
        a=c(1, 0),
        b=c(1, 1),
        c=c(0, 1),
        d=c(0, 0),
        x=c(2, 5)
    )

    result = upset_data(tibble::tibble(df), c('a', 'b', 'c', 'd'))

    expected_matrix = data.frame(
        `a-b`=c(d=FALSE, a=TRUE, c=FALSE, b=TRUE),
        `b-c`=c(d=FALSE, a=FALSE, c=TRUE, b=TRUE),
        check.names = FALSE
    )

    expect_equal(
        result$matrix,
        expected_matrix
    )
})
