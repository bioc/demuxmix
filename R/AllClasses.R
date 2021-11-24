#' A class representing a set of mixture models fitted to HTO data.
#'
#' An object of this class is returned by \code{\link{demuxmix}} and
#' stores a fitted mixture model for each hashtag of the given dataset and 
#' additional information about model fitting. Users should not directly
#' initialize this class but can apply various plotting functions and
#' extract information from an object of \code{Demuxmix}. For example,
#' \code{\link{dmmClassify}} returns the cell-to-HTO assignments obtained from
#' the models stored in the \code{Demuxmix} object. Please see the package's
#' vignette for how to work with an object of this class.
#' 
#' @param object An \code{Demuxmix} object.
#' @param value Value between 0 and 1 specifying the acceptance probability,
#'   i.e., the minimum posterior probability required to assign a cell to
#'   an HTO.
#' @param ... Additional arguments forwarded to summary (ignored).
#' 
#' @slot models A list of mixture models. One model per hashtag.
#' @slot outliers A logical matrix of size HTO x cells identifying outlier 
#'   values excluded from model fitting.
#' @slot clusterInit A numeric matrix of size HTO x cells with the class
#'   memberships used to initialize model fitting. A value of 1 corresponds to
#'   the negative component and a value of 2 to the positive component.
#' @slot posteriorProb A numeric matrix of size HTO x cells with the posterior
#'   probabilities that a cell is positive for a hashtag.
#' @slot tailException A logical matrix of size HTO x cells identifying
#'   posterior probabilities that would be adjusted based on the exception
#'   rules defined when calling \code{\link{demuxmix}} to correct inaccuracies
#'   at the extreme tails of the mixture distributions. See
#'   \code{\link{demuxmix}} for details.
#' @slot modelSelection A \code{data.frame} with information about the model
#'   selection process if parameter \code{model} was set to 'auto'. Empty 
#'   \code{data.frame} if model was specified.
#' @slot parameters A list with the \code{\link{demuxmix}} parameters
#'   used to generate the model represented by this class.
#'
#' @details All matrices stored by \code{Demuxmix} have the same dimension and
#'   the same row and column names as the original matrix \code{hto} passed to
#'   \code{\link{demuxmix}}. The mixture models in slot \code{models} are
#'   stored in an internal class format.
#' 
#' @seealso \code{\link{dmmClassify}} to obtain classification results.
#'   \code{\link{plotDmmHistogram}}, \code{\link{plotDmmScatter}},
#'   \code{\link{plotDmmPosteriorP}}, and \code{\link{dmmOverlap}} to assess
#'   the model fit.
#'   
#' @examples
#' set.seed(2642)
#' simdata <- dmmSimulateHto(class=rbind(c(rep(TRUE, 220), rep(FALSE, 200)),
#'                                       c(rep(FALSE, 200), rep(TRUE, 220))))
#' 
#' dmm <- demuxmix(simdata$hto, rna=simdata$rna, p.acpt=0.9)
#' p.acpt(dmm)
#' head(dmmClassify(dmm))
#' dmm@parameters
#' 
#' @aliases show,Demuxmix-method summary,Demuxmix-method
#'   p.acpt p.acpt,Demuxmix-method p.acpt<- p.acpt<-,Demuxmix,numeric-method 
#' 
#' @importFrom methods setClass new is
#' @exportClass Demuxmix
Demuxmix <- setClass("Demuxmix",
  slots=c(models="list",
          outliers="matrix",
          clusterInit="matrix",
          posteriorProb="matrix",
          tailException="matrix",
          modelSelection="data.frame",
          parameters="list"),
  validity=function(object) {
    if(!all(sapply(object@models, is, "NaiveMixModel") |
            sapply(object@models, is, "RegMixModel"))) {
      return("models must contain objects of class NaivMixModel or RegMixModel.")
    }
    if (any(is.na(object@posteriorProb))) {
      return("posteriorProb must not contain missing values.")
    }
    if (any(object@posteriorProb < 0) | any(object@posteriorProb > 1)) {
      return("All values in posteriorProb must be in [0, 1].")
    }
    if (!is.element("p.acpt", names(object@parameters))) {
      return("p.acpt must be element in parameters.")
    }
    if (object@parameters$p.acpt < 0 | object@parameters$p.acpt > 1) {
      return("p.acpt given in parameters must be in [0, 1].")
    }
    return(TRUE)
  }
)


# Internal class representing a naive mixture model
# fitted to a single hastag oligo.
#' @importFrom methods setClass
NaiveMixModel <- setClass("NaiveMixModel",
  slots=c(mu1="numeric",
          mu2="numeric",
          theta1="numeric",
          theta2="numeric",
          pi="numeric",
          hto="numeric",
          htoId="character",
          parameters="list",
          log="data.frame",
          converged="logical"),
  validity=function(object) {
    if (length(object@mu1) > 1 |  length(object@mu2) > 1 |
        length(object@theta1) > 1 | length(object@theta1) > 1) {
      return("mu and theta must have length 1.")
    }
    if (object@mu1 > object@mu2) {
      return("mu1 must be smaller than mu2.")
    }
    if (object@theta1 <= 0 | object@theta2 <= 0) {
      return("theta1 and theta2 must be larger than 0.")
    }
    if (length(object@pi) != 2) {
      return("pi must be of length 2.")
    }
    if (any(object@pi < 0) | any(object@pi > 1)) {
      return("pi must be 0 <= pi <= 1.")
    }
    if (any(object@hto < 0)) {
      return("hto contain positive numbers.")
    }
    return(TRUE)
  }
)


# Internal class representing a regression mixture model
# fitted to a single hastag oligo.
#' @importFrom methods setClass
RegMixModel <- setClass("RegMixModel",
  slots=c(fit1="ANY",
          fit2="ANY",
          pi="numeric",
          htoId="character",
          parameters="list",
          log="data.frame",
          converged="logical"),
  validity=function(object) {
    if (length(object@fit1$y) != length(object@fit2$y)) {
      return("Both models must be fitted to the same data.")
    }
    if (! "rna" %in% colnames(object@fit2$model)) {
      return("rna must be a covariate of the second model.")
    }
    if (length(object@pi) !=2) {
      return("pi must be of length 2.")
    }
    if (any(object@pi < 0) | any(object@pi > 1)) {
      return("pi must be 0 <= pi <= 1.")
    }
    return(TRUE)
  }
)