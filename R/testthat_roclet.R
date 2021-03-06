# Adapted from roxygen2's
# https://github.com/klutometis/roxygen/blob/master/R/rd.R

#' @importFrom roxygen2 roxy_tag_parse
#' @export
roxy_tag_parse.roxy_tag_tests <- function(x) {
  if (x$raw == "") {
    return(roxy_tag_warning(x, "requires a value"))
  }
  
  x$val <- gsub("^\n", "", x$raw)
  
  return(x)
}

#' Roclet: make testthat test-files.
#'
#' @family roclets
#' @description This roclet is the workhorse of roxytest, 
#' producing the testthat test files specified.
#' 
#' Generally you will not call this function directly
#' but will instead use roxygenise() specifying the testthat roclet
#' 
#' @seealso Other roclets:
#' \code{\link{param_roclet}}, 
#' \code{\link[roxygen2]{namespace_roclet}}, 
#' \code{\link[roxygen2]{rd_roclet}},
#' \code{\link[roxygen2]{vignette_roclet}}.
#' 
#' @importFrom roxygen2 roclet
#' 
#' @export
testthat_roclet <- function() {
  return(roxygen2::roclet("testthat"))
}

#' @importFrom roxygen2 roclet_process
#' @export
roclet_process.roclet_testthat <- function(x,
                                           blocks,
                                           env,
                                           base_path) {
  
  testfiles <- list()
  
  for (block in blocks) {
    testthat <- block_to_testthat(block, 
                                  base_path = base_path, 
                                  env = env)
    
    if (is.null(testthat$filename) || is.null(testthat$tests)) {
      next
    }
    
    
    testfiles[[testthat$filename]] <- c(testfiles[[testthat$filename]], 
                                        list(testthat))
  }
  
  if (length(testfiles) == 0L) {
    return(list())
  }
  
  ######################################
  
  paths <- names(testfiles)
  
  results <- lapply(seq_along(testfiles), function(i) {
    testfile <- testfiles[[i]]
    
    content <- lapply(testfile, function(x) {
      tests <- lapply(x$tests, function(l) l$val)
      
      tests <- gsub("^\\s*(.*?)\\s*$", "\\1", tests)
      tests_indented <- paste0("  ", gsub("\n", "\n  ", tests, fixed = TRUE))
      tests_name <- x$functionname
      
      paste0('test_that("', tests_name, '", {', "\n", 
             tests_indented, "\n",
             "})\n")
    })
    
    content <- paste0(content, collapse = "\n\n")
    
    path_quoted <- if (paths[i] == "<text>") {
      path_quoted <- paths[i]
    } else {
      path_quoted <- paste0('File R/', auto_quote(paths[i]))
    }
    
    content <- paste0("# Generated by roxytest: Do not edit by hand!\n", 
                      "# Last updated: ", as.character(Sys.time()), "\n\n",
                      'context("', path_quoted, '")', "\n\n",
                      content)
    
    return(content)
  })
  
  names(results) <- paths
  
  return(results)
}

#' @importFrom roxygen2 block_get_tags
block_to_testthat <- function(block, base_path, env) {
  testthat_file <- list()
  
  tests <- roxygen2::block_get_tags(block, "tests")
  
  if (length(tests) == 0L) {
    return(NULL)
  }

  testthat_file$tests <- tests
  
  filename <- basename(block$file)

  testthat_file$filename <- filename
  
  testthat_file$functionname <- 
    if (!is.null(block$object) && !is.null(block$object$alias)) {
      paste0('Function ', auto_quote(block$object$alias), '()')
    } else {
      "[unknown alias]"
    }
  
  if (!is.null(block$line)) {
    testthat_file$functionname <- paste0(testthat_file$functionname, ' @ L', block$line)
  }
  
  return(testthat_file)
}

#' @importFrom roxygen2 roclet_output
#' @export
roclet_output.roclet_testthat <- function(x, results, base_path, ...) {
  verify_testthat_used()
  
  roclet_clean.roclet_testthat(x, base_path)
  
  testthat_path <- normalizePath(file.path(base_path, "tests", "testthat"))
  
  paths <- names(results)
  
  for (i in seq_along(results)) {    
    path <- file.path(testthat_path, paste0("test-roxytest-", paths[i]))
    
    if (file.exists(path)) {
      warning(paste0("The file '", path, "' was not created by roxytest (wrong header), ", 
                     "and hence was not modified as planned. ",
                     "Please be sure that this is intended."))
      next
    }
    
    content <- results[[i]]
    
    writeLines(text = enc2utf8(content), 
               con = path, 
               useBytes = TRUE)
  }
  
  return(paths)
}

#' @importFrom roxygen2 roclet_clean
#' @export
roclet_clean.roclet_testthat <- function(x, base_path) {
  verify_testthat_used()
  
  testfiles <- dir(path = file.path(base_path, "tests", "testthat"), 
                   pattern = "^test-roxytest-.*\\.R$", 
                   full.names = TRUE)
  testfiles <- testfiles[!file.info(testfiles)$isdir]
  
  made_by_me <- vapply(testfiles, made_by_roxytest, logical(1))
  
  if (sum(!made_by_me) > 0) {
    warning(paste0("Clean-up: Some files in tests/testthat/ with the file name pattern ", 
                   "test-roxytest-*.R was not created by roxytest (missing header), ", 
                   "and hence was not removed. ",
                   "Please be sure that this is intended."))
  }
  
  unlink(testfiles[made_by_me])
}

