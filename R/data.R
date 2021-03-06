#' @importFrom utils stack
NULL

EMPTY_INTERSECTION = 'NOT_IN_EITHER_GROUP'

sanitize_names = function(variables_names) {
    sanitized_names = c()
    for (name in variables_names) {
        if (grepl('-', name, fixed=TRUE)) {
            original_name = name
            name = gsub('-', '_', name)
            if (name %in% variables_names) {
            stop(paste(
                'The group names contain minus characters (-) which prevent intersections names composition;',
                'offending group:', original_name, 'please substitute these characters using gsub and try again.'
            ))
            }
        }
        sanitized_names = c(sanitized_names, name)
        }
    sanitized_names
}


names_of_members = function(row) {
  # the original implementation used which()
  #    members = names(which(row))
  # but which() is doing a few more things that are not needed;
  # it is an equivalent to seq_along(x)[!is.na(x) & x] + names assignment
  # and those steps can be omitted

  members = names(row)[row]
  if (length(members) != 0) {
      paste(members, collapse='-')
  } else {
      # this optimization may not be beneficial for dense matrices,
      # but we could add a heuristic that checks if the matrix is dense
      ''
  }
}


get_intersection_members = function(x) {
    strsplit(x, '-', fixed=TRUE)
}


gather = function(data, idvar, col_name, value_name='value') {
    not_idvar = colnames(data)
    not_idvar = not_idvar[not_idvar != idvar]
    result <- stack(data, select=not_idvar)
    result$group <- as.factor(rep(data[[idvar]], times=ncol(data) - 1))
    colnames(result) = c(value_name, col_name, idvar)
    result
}


compute_matrix = function(sorted_intersections, sorted_groups) {
    intersections_as_groups = get_intersection_members(sorted_intersections)

     matrix = sapply(
        intersections_as_groups,
        function(i_groups) {
            sorted_groups %in% i_groups
        },
        simplify=FALSE
    )

    matrix_data = as.data.frame(matrix, row.names=sorted_groups)
    colnames(matrix_data) = sorted_intersections
    matrix_data
}


compute_unions = function(data, sorted_intersections) {
    intersections_as_groups = get_intersection_members(sorted_intersections)

    result = sapply(
        intersections_as_groups,
        function(i_groups) {
            ids_of_union_for_intersection = data[data$group %in% i_groups, 'id']

            # deduplicated = union_for_intersection[!duplicated(ids), ]
            # nrow(deduplicated)

            # note nrow(deduplicated) == sum(!duplicated(ids))

            # NOTE:
            # union: nrow(deduplicated)
            # sum of counts: nrow(union_for_intersection)

            sum(!duplicated(ids_of_union_for_intersection))
        },
        simplify=TRUE
    )
    names(result) = sorted_intersections
    result
}


check_argument = function(
    value,
    allowed,
    description
) {
    if (!(value %in% allowed)) {
        stop(
            paste0(
                description,
                ' has to be one of: ',
                paste(allowed, collapse=' or '),
                ', not "',
                value,
                '"'

            )
        )
    }
}


check_sort = function(
    sort_order,
    allowed = c('descending', 'ascending'),
    what = 'order'
) {

    if (sort_order == FALSE) {
        return(TRUE)
    }

    check_argument(
        sort_order,
        allowed,
        paste('Sort', what)
    )

    TRUE
}


get_sort_order = function(data, sort_order) {
    check_sort(sort_order)

    if (sort_order == 'descending') {
        do.call(order, data)
    } else {
        do.call(order, lapply(data, function(x) {-x}))
    }
}


calculate_degree = function(x) {
    values = lengths(get_intersection_members(x))
    values[x == EMPTY_INTERSECTION] = 0
    values
}


trim_intersections = function(
    intersections_by_size, min_size=0, max_size=Inf,
    min_degree=0, max_degree=Inf,
    n_intersections=NULL
) {
    intersections_by_size = intersections_by_size[
        (intersections_by_size >= min_size)
        &
        (intersections_by_size <= max_size)
    ]
    if (min_degree > 0 || max_degree != Inf) {
        degrees = calculate_degree(names(intersections_by_size))
        intersections_by_size = intersections_by_size[
            (degrees >= min_degree)
            &
            (degrees <= max_degree)
        ]
    }

    if (!is.null(n_intersections)) {
        intersections_by_size = tail(
            sort(intersections_by_size),
            n_intersections
        )
    }

    intersections_by_size
}


#' Prepare data for UpSet plots
#'
#' @param data a dataframe including binary columns representing membership in classes
#' @param intersect which columns should be used to compose the intersection
#' @param min_size minimal number of observations in an intersection for it to be included
#' @param max_size maximal number of observations in an intersection for it to be included
#' @param min_degree minimal degree of an intersection for it to be included
#' @param max_degree maximal degree of an intersection for it to be included
#' @param n_intersections the exact number of the intersections to be displayed; n largest intersections that meet the size and degree criteria will be shown
#' @param keep_empty_groups whether empty sets should be kept (including sets which are only empty after filtering by size)
#' @param warn_when_dropping_groups whether a warning should be issued when empty sets are being removed
#' @param warn_when_converting whether a warning should  be issued when input is not boolean
#' @param sort_sets whether to sort the rows in the intersection matrix (descending sort by default); one of: `'ascending'`, `'descending'`, `FALSE`
#' @param sort_intersections whether to sort the columns in the intersection matrix (descending sort by default); one of: `'ascending'`, `'descending'`, `FALSE`
#' @param sort_intersections_by the mode of sorting, the size of the intersection (cardinality) by default; one of: `'cardinality'`, `'degree'`, `'ratio'`, or any combination of these (e.g. `c('degree', 'cardinality')`)
#' @param group_by the mode of grouping intersections; one of: `'degree'`, `'sets'`
#' @param min_max_early whether the min and max limits should be applied early (for faster plotting), or late (for accurate depiction of ratios)
#' @param union_count_column name of the column to store the union size (adjust if conflicts with your data)
#' @param intersection_count_column name of the column to store the intersection size (adjust if conflicts with your data)
#' @export
upset_data = function(
    data, intersect, min_size=0, max_size=Inf, min_degree=0, max_degree=Inf,
    n_intersections=NULL,
    keep_empty_groups=FALSE,
    warn_when_dropping_groups=FALSE,
    warn_when_converting='auto',
    sort_sets='descending',
    sort_intersections='descending',
    sort_intersections_by='cardinality',
    group_by='degree',
    min_max_early=TRUE,
    union_count_column='union_size',
    intersection_count_column='intersection_size'
) {
    if ('tbl' %in% class(data)) {
        data = as.data.frame(data)
    }

    check_sort(sort_sets)

    for (by in sort_intersections_by) {
        check_sort(by, allowed=c('cardinality', 'degree', 'ratio'), what='method')
    }

    intersect = unlist(intersect)
    if (length(intersect) == 1) {
        stop('Needs at least two indicator variables')
    }

    # convert to logical if needed
    is_column_logical = sapply(data[, intersect], is.logical)
    if (any(!is_column_logical)) {
        non_logical = names(is_column_logical[is_column_logical == FALSE])

        if (warn_when_converting == 'auto') {
            unique_values = unique(
                as.vector(
                    as.matrix(
                        data[, non_logical]
                    )
                )
            )
            if (setequal(unique_values, c(0, 1))) {
                warn_when_converting = FALSE
            } else {
                warn_when_converting = TRUE
            }
        }
        if (warn_when_converting) {
            warning(paste('Converting non-logical columns to binary:', paste(non_logical, collapse=', ')))
        }

        data[, non_logical] = sapply(data[, non_logical], as.logical)
    }

    intersect_in_order_of_data = colnames(data)[colnames(data) %in% intersect]
    colnames(data)[colnames(data) %in% intersect] <- sanitize_names(intersect_in_order_of_data)
    non_sanitized_labels = intersect
    intersect = sanitize_names(intersect)
    names(non_sanitized_labels) = intersect

    data$intersection = apply(
      data[intersect], 1,
      names_of_members
    )
    data$intersection[data$intersection == ''] = EMPTY_INTERSECTION

    intersections_by_size = table(data$intersection)

    plot_intersections_subset = names(intersections_by_size)
    plot_sets_subset = intersect

    if (min_size > 0 || max_size != Inf || min_degree > 0 || max_degree != Inf || !is.null(n_intersections)) {

        intersections_by_size_trimmed = trim_intersections(
            intersections_by_size,
            min_size=min_size,
            max_size=max_size,
            min_degree=min_degree,
            max_degree=max_degree,
            n_intersections=n_intersections
        )
        data_subset = data[data$intersection %in% names(intersections_by_size_trimmed), ]

        # once the unused intersections are removed, we need to decide
        # if the groups not participating in any of the intersections should be kept or removed
        if (!keep_empty_groups) {
            itersect_data = data_subset[, intersect]
            is_non_empty = sapply(itersect_data, any)
            empty_groups = names(itersect_data[!is_non_empty])
            if (length(empty_groups) != 0 && warn_when_dropping_groups) {
                to_display = ifelse(
                    length(empty_groups) <= 5,
                    paste('Dropping empty groups:', paste(empty_groups, collapse=', ')),
                    paste('Dropping', length(empty_groups), 'empty groups')
                )
                warning(to_display)
            }
            intersect_subset = intersect[!(intersect %in% empty_groups)]
        } else {
            intersect_subset = intersect
        }

        if (min_max_early == TRUE) {
            intersections_by_size = intersections_by_size_trimmed

            if (!keep_empty_groups) {
                intersect = intersect_subset
                data = data_subset
            }
        }

        plot_intersections_subset = names(intersections_by_size_trimmed)
        plot_sets_subset = intersect_subset
    }

    stacked = stack(data, intersect)
    stacked$id = rep(1:nrow(data), length(intersect))
    stacked = stacked[stacked$values == TRUE, ]

    metadata = data[
          match(
              stacked$id,
              1:nrow(data)
          ),
          setdiff(colnames(data), intersect)
    ]
    stacked = cbind(stacked, metadata)

    stacked$group = stacked$ind

    groups_by_size = table(stacked$group)
    if (sort_sets != FALSE) {
        groups_by_size = groups_by_size[get_sort_order(list(groups_by_size), sort_sets)]
    } else {
        groups_by_size = groups_by_size[names(groups_by_size)]
    }
    sorted_groups = names(groups_by_size)

    if (sort_intersections != FALSE) {

        sort_values = lapply(
            sort_intersections_by,
            function(by) {
                if (by == 'cardinality') {
                    sort_value = intersections_by_size
                } else if (by == 'degree') {
                    original_intersections_names = names(intersections_by_size)
                    sort_value = calculate_degree(original_intersections_names)
                    names(sort_value) = original_intersections_names
                } else if (by == 'ratio') {
                    unsorted_union_sizes = compute_unions(stacked, names(intersections_by_size))
                    sort_value = intersections_by_size
                    sort_value = sort_value / unsorted_union_sizes
                }
                sort_value
            }
        )

        intersections_by_size = intersections_by_size[
            get_sort_order(sort_values, sort_intersections)
        ]
    }

    check_argument(
        group_by,
        allowed=c('degree', 'sets'),
        description='group_by'
    )

    unique_sorted_intersections = names(intersections_by_size)

    if (group_by == 'degree') {
        sorted_intersections = unique_sorted_intersections
    } else if (group_by == 'sets') {
        new_plot_intersections_subset = c()
        sorted_intersections = c()

        intersections_indices = list()
        new_intersection_column = list()
        group_by_group_column = list()

        for (group in sorted_groups) {
            for (intersection in unique_sorted_intersections) {
                i_groups = unlist(get_intersection_members(intersection))
                if (group %in% i_groups) {
                    new_intersection_id = paste(c(group, i_groups[i_groups!=group]), collapse='-')
                    sorted_intersections = c(sorted_intersections, new_intersection_id)
                    intersections_by_size[new_intersection_id] = intersections_by_size[intersection]

                    intersection_ids = which(data$intersection == intersection)

                    intersections_indices[[length(intersections_indices) + 1]] = intersection_ids
                    new_intersection_column[[length(new_intersection_column) + 1]] = rep(
                        new_intersection_id,
                        length(intersection_ids)
                    )
                    group_by_group_column[[length(group_by_group_column) + 1]] = rep(
                        group,
                        length(intersection_ids)
                    )

                    if (intersection %in% plot_intersections_subset) {
                        new_plot_intersections_subset = c(
                            new_plot_intersections_subset, new_intersection_id
                        )
                    }
                }
            }
        }
        data = data[unlist(intersections_indices), ]
        data$intersection = unlist(new_intersection_column)
        data$group_by_group = unlist(group_by_group_column)

        plot_intersections_subset = new_plot_intersections_subset
    }

    matrix_data = compute_matrix(sorted_intersections, sorted_groups)

    group = rownames(matrix_data)

    matrix_frame = gather(
        cbind(group, matrix_data),
        'group',
        'intersection',
        'value'
    )

    if (group_by == 'sets') {
        # the set (group) by which the intersections were grouped is stored as the first element of "intersection"
        # extract first element of intersection:
        matrix_frame$group_by_group = sapply(
            get_intersection_members(
                as.character(matrix_frame$intersection)
            ),
            '[[',
            1
        )
    }

    union_sizes = compute_unions(stacked, sorted_intersections)

    with_sizes = data.frame(data)

    with_sizes[[union_count_column]] = union_sizes[data$intersection]
    with_sizes[[intersection_count_column]] = intersections_by_size[data$intersection]

  list(
    with_sizes=with_sizes,
    sets_ordering_in_ids=intersect,
    intersected=data,
    presence=stacked,
    matrix=matrix_data,
    matrix_frame=matrix_frame,
    sorted=list(
      groups=sorted_groups,
      intersections=sorted_intersections
    ),
    union_sizes=union_sizes,
    plot_intersections_subset=plot_intersections_subset,
    plot_sets_subset=plot_sets_subset,
    non_sanitized_labels=non_sanitized_labels
  )
}
