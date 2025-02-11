#' @export
makeTSPSolver.lkh = function() {
  makeTSPSolverInternal(
    cl = "lkh",
    short.name = "LKH",
    name = "Lin-Kernigham Heuristic",
    properties = c("euclidean", "external", "requires.tsplib"),
    par.set = makeParamSet(
      makeIntegerLearnerParam(id = "runs", default = 1L, lower = 1L),
      makeIntegerLearnerParam(id = "seed", default = 1L, lower = 1L),
      makeIntegerLearnerParam(id = "cutoff.time", default = 999999999L),
      makeNumericLearnerParam(id = "opt.tour.length", default = 0, lower = 0),
      makeIntegerLearnerParam(id = "max.trials", default = 100000000L, lower = 1L)
    )
  )
}

#' @export
# @interface see runTSPSolver
run.lkh = function(solver, instance, solver.pars, ...) {
  temp.dir = tempdir()
  cur.dir = getwd()
  on.exit(setwd(cur.dir))
  setwd(temp.dir)

  temp.file = basename(tempfile(tmpdir = temp.dir))
  file.params = paste0(temp.file, ".par")
  file.output = paste0(temp.file, ".out")

  has.temporary.input = FALSE
  if (testClass(instance, "Network")) {
    has.temporary.input = TRUE
    file.input = paste0(temp.file, ".tsp")
    netgen::exportToTSPlibFormat(instance, filename = file.input, full.matrix = TRUE, use.extended.format = FALSE)
  } else {
    file.input = instance
  }

  # the most important parameters are the PROBLEM_FILE, the number of RUNS,
  # the initial SEED for the generator of pseudo random numbers and TIME_LIMIT
  # in seconds.
  args = list()
  args$PROBLEM_FILE = file.input
  args$RUNS = coalesce(solver.pars$runs, 1L)
  args$SEED = coalesce(solver.pars$seed, 1L)
  args$TIME_LIMIT = coalesce(solver.pars$cutoff.time, 999999L)
  args$MAX_TRIALS = coalesce(solver.pars$max.trials, 999999L)

  if (!is.null(solver.pars$opt.tour.length)) {
    args$OPTIMUM = solver.pars$opt.tour.length
    args$STOP_AT_OPTIMUM = "YES"
  }

  writeToLKHParameterFile = function(file.params, args) {
    args = sapply(names(args), function(name) {
      sprintf("%s = %s", name, args[[name]])
    })
    output = collapse(args, "\n")
    write(output, file = file.params)
  }

  args$OUTPUT_TOUR_FILE = file.output
  writeToLKHParameterFile(file.params, args)

  # second parameter is time limit
  lkh.args = c(file.params, args$TIME_LIMIT)

  # prepare output
  tour = NA
  tour.length = NA
  error = NULL
  #runsolver.output = NA

  # here we append the binary file and runsolver stuff
  # runsolver.file = tempfile()
  # lkh.args = c("-C", solver.pars$stop.on.cutoff.time, "-w", runsolver.file, lkh.bin, lkh.args)

  # Write specific parameter file (deleted later)
  # $ in the output file name is replaced by tour length by LKH (see USER GUIDE)
  res = try(suppressWarnings(system2(solver$bin, lkh.args, stdout = TRUE, stderr = TRUE)))

  # read runsolver output
  # runsolver.con = file(runsolver.file, "r")
  # runsolver.output = readLines(runsolver.con)
  # close(runsolver.con)
  # unlink(runsolver.file)

  # algorithm failed probably: try to determine if he was successful but had not enough time to terminate
  # if (!file.exists(output.file)) {
  #   catf("Most probably %s did not finish before time limit was reached.", lkh.bin)
  #   error = "Most probably the algorithm reached the time limit."
  #   if (!is.null(res)) {
  #     # go through the stdout/strerr output line by line and search for the last useful output,
  #     # i.e., output of the shortest tour length so far
  #     last.output = res
  #     for (i in length(last.output):1L) {
  #       output.line = last.output[i]
  #       bags = str_extract_all(output.line, pattern = "Cost = [0-9]+")[[1L]]
  #       if (length(bags) == 1L) {
  #         tour.length = as.integer(str_split(bags, " = ")[[1L]][2L])
  #         break
  #       }
  #     }
  #   }
  # } else {
  # build tour
  tmp = readTSPlibTOURFile(file.output)
  tour = tmp$tour
  tour.length = tmp$tour.length

  unlink(c(file.output, file.params))
  if (has.temporary.input) {
    unlink(file.input)
  }

  return(list(
      "tour" = tour,
      "tour.length" = tour.length,
      "error" = error,
      solver.output = res
    )
  )
}
