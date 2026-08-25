# Xsens MVNX (MVN Analyze XML export) ingestion.
#
# An .mvnx file holds a <subject> with a segment list, a joint list, and a
# sequence of <frame> elements. Each "normal" frame carries space-separated
# per-segment kinematics (position, orientation, velocity, acceleration, ...),
# per-joint angles, and the centre of mass. All signals share the subject frame
# rate; each becomes a stream of a MultiRatePhysioExperiment.

# signal tag -> (stream name, values per element, channel-axis suffixes, whether
# the element count is segments or joints or a single centre-of-mass triple).
.MVNX_SIGNALS <- list(
  list(tag = "position",             name = "position",        per = "segment", suffix = c("_x", "_y", "_z")),
  list(tag = "orientation",          name = "orientation",     per = "segment", suffix = c("_q0", "_q1", "_q2", "_q3")),
  list(tag = "velocity",             name = "velocity",        per = "segment", suffix = c("_x", "_y", "_z")),
  list(tag = "acceleration",         name = "acceleration",    per = "segment", suffix = c("_x", "_y", "_z")),
  list(tag = "angularVelocity",      name = "angularVelocity", per = "segment", suffix = c("_x", "_y", "_z")),
  list(tag = "angularAcceleration",  name = "angularAccel",    per = "segment", suffix = c("_x", "_y", "_z")),
  list(tag = "jointAngle",           name = "jointAngle",      per = "joint",   suffix = c("_x", "_y", "_z")),
  list(tag = "centerOfMass",         name = "centerOfMass",    per = "com",     suffix = c("_x", "_y", "_z")))

# Extract one signal across all frames into a numeric matrix (nframes x nchan).
.mvnx_matrix <- function(frames, tag) {
  nodes <- lapply(frames, function(fr) xml2::xml_find_first(fr, paste0("./", tag)))
  present <- !vapply(nodes, function(n) inherits(n, "xml_missing"), logical(1))
  if (!any(present)) return(NULL)
  rows <- lapply(nodes, function(n) {
    if (inherits(n, "xml_missing")) return(numeric(0))
    as.numeric(strsplit(trimws(xml2::xml_text(n)), "\\s+")[[1]])
  })
  # The channel count is fixed by the schema; take it from the first frame that
  # carries this tag (a single corrupt/oversized frame must not redefine it).
  ncol <- lengths(rows)[present][1]
  if (is.na(ncol) || ncol == 0) return(NULL)
  m <- matrix(NA_real_, nrow = length(rows), ncol = ncol)
  dropped <- 0L
  for (i in seq_along(rows)) {
    if (length(rows[[i]]) == ncol) {
      m[i, ] <- rows[[i]]
    } else if (length(rows[[i]]) > 0) {
      dropped <- dropped + 1L
    }
  }
  if (dropped > 0) {
    warning(sprintf(
      "%d '%s' frame(s) had an unexpected value count and were left as NA",
      dropped, tag), call. = FALSE)
  }
  m
}

#' Read an Xsens MVNX motion-capture export
#'
#' Parses an Xsens MVN Analyze `.mvnx` XML file into a
#' [PhysioCore::MultiRatePhysioExperiment]. Each kinematic signal present in the
#' "normal" frames (segment position, orientation, velocity, acceleration,
#' angular velocity/acceleration, per-joint angles, and centre of mass) becomes
#' a stream at the subject frame rate, with per-channel labels built from the
#' segment/joint names.
#'
#' @param path Path to a `.mvnx` file.
#' @return A [PhysioCore::MultiRatePhysioExperiment].
#' @references Xsens. "MVNX file format (MVN Analyze)."
#' @seealso [readBIOPAC()], [readDelsysTrigno()]
#' @export
#' @examples
#' f <- system.file("extdata", "xsens_sample.mvnx", package = "PhysioDevices")
#' if (nzchar(f) && requireNamespace("xml2", quietly = TRUE)) {
#'   mr <- readXsensMVNX(f)
#'   PhysioCore::streamNames(mr)
#' }
readXsensMVNX <- function(path) {
  if (!file.exists(path)) stop("MVNX file not found: ", path, call. = FALSE)
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop("Package 'xml2' is required to read MVNX files.", call. = FALSE)
  }
  doc <- xml2::read_xml(path)
  xml2::xml_ns_strip(doc)

  subject <- xml2::xml_find_first(doc, "//subject")
  if (inherits(subject, "xml_missing")) {
    stop("not an MVNX file (no <subject> element): ", path, call. = FALSE)
  }
  frame_rate <- as.numeric(xml2::xml_attr(subject, "frameRate"))
  if (is.na(frame_rate) || frame_rate <= 0) frame_rate <- 1

  seg_labels <- xml2::xml_attr(
    xml2::xml_find_all(doc, "//segments/segment"), "label")
  joint_labels <- xml2::xml_attr(
    xml2::xml_find_all(doc, "//joints/joint"), "label")
  frames <- xml2::xml_find_all(doc, "//frames/frame[@type='normal']")
  if (length(frames) == 0) {
    stop("MVNX file has no motion ('normal') frames: ", path, call. = FALSE)
  }

  streams <- list()
  for (s in .MVNX_SIGNALS) {
    m <- .mvnx_matrix(frames, s$tag)
    if (is.null(m)) next
    labels <- .mvnx_labels(s, seg_labels, joint_labels, ncol(m))
    colnames(m) <- labels
    pe <- PhysioExperiment(
      assays = S4Vectors::SimpleList(raw = m),
      colData = S4Vectors::DataFrame(label = labels),
      metadata = list(source_device = "Xsens MVN", signal = s$name,
                      coordinate_frame = "global",
                      units = if (s$name == "orientation") "quaternion"
                              else if (s$name == "jointAngle") "deg" else "m"),
      samplingRate = frame_rate)
    streams[[s$name]] <- logStep(pe, "readXsensMVNX",
                                 params = list(signal = s$name))
  }
  if (length(streams) == 0) {
    stop("no decodable kinematic signals found in MVNX: ", path, call. = FALSE)
  }
  offsets <- stats::setNames(rep(0, length(streams)), names(streams))
  MultiRatePhysioExperiment(streams = streams, offsets = offsets,
                            reference_rate = frame_rate, t0 = 0)
}

# Build channel labels for one signal from segment/joint names.
.mvnx_labels <- function(s, seg_labels, joint_labels, ncol) {
  base <- switch(s$per,
                 segment = seg_labels,
                 joint = joint_labels,
                 com = "CoM")
  labels <- as.vector(t(outer(base, s$suffix, paste0)))
  if (length(labels) != ncol) labels <- paste0(s$name, seq_len(ncol))
  labels
}
