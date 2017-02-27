% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/attributes.R
\name{rotation}
\alias{rotation}
\alias{rotation<-}
\alias{set_rotation}
\title{Get or Set Cell Text Rotation}
\usage{
rotation(ht)
rotation(ht) <- value
set_rotation(ht, row, col, value)
}
\arguments{
\item{ht}{A huxtable.}

\item{value}{A numeric vector. 0 is normal direction, 90 is going up, etc. Set to \code{NA} to reset to the default.}

\item{row}{A row specifier.}

\item{col}{A column specifier.}
}
\value{
For \code{rotation}, the \code{rotation} attribute. For \code{rotation<-}, the
value of the right hand side (technically, the function itself returns the \code{ht} object, but this is an
implementation detail of how R handles replacement functions). For \code{set_rotation}, the \code{ht} object.
}