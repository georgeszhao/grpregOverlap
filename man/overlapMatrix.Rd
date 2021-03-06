\name{overlapMatrix}
\alias{overlapMatrix}
\title{
Compute a matrix indicating overlaps between groups
}

\description{
Compute a matrix indicating the number of overlaps between groups.
}
\usage{
overlapMatrix(X, group)
}

\arguments{
  \item{X}{
  The design matrix, without an intercept, as in \code{grpregOverlap}.
  }
  \item{group}{
  A list of vectors containing group information, as in \code{grpregOverlap}.
  }
}

\details{
This function is intended to provide an interface for users to check the overlapping structure among groups.
}

\value{
A square (sparse) matrix \eqn{C}:  \eqn{C[i, j]} is the number of overlapped variables between group i and j. Diagonal value \eqn{C[i, i]} is the number of variables in group i.
}

\author{
Yaohui Zeng <yaohui-zeng@uiowa.edu>
}

\examples{
data(pathway.dat)
X <- pathway.dat$expression
group <- pathway.dat$pathways
overlap.mat <- overlapMatrix(X, group)
}
