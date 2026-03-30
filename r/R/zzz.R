# ::rtemis.a3::
# 2024- EDG rtemis.org

rtemis.a3_version <- utils::packageVersion("rtemis.a3")

.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    paste0(
      pkglogo(pkg = pkgname),
      "\n.:",
      pkgname,
      " ",
      rtemis.a3_version,
      " \U1F9EC",
      " ",
      utils::sessionInfo()[[2]]
    )
  )
}
