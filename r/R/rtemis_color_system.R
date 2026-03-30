# %% rtemis_color_system ----
rtemis_light_teal <- "#00fdfd"
rtemis_teal <- "#00b2b2"
rtemis_light_blue <- "#30cefe"
kaimana_red <- "#ff004c"
kaimana_blue <- "#0067e0"
kaimana_light_blue <- "#479cff"
coastside_orange <- "#ff9f20"
rtemis_orange <- "#ff4f36"
kaimana_green <- "#00ffb3"
kaimana_med_green <- "#00996b"
rtemis_purple <- "#6125f7"
rtemis_magenta <- "#912ac8"
rtemis_light_magenta <- "#b25bd6"
magenta <- "#ff00ff"
lmd_burgundy <- "#a92459"
rtms_gray <- "#808080"


# %% internal colors ----
rt_gray <- rtms_gray
rt_red <- kaimana_red
rt_blue <- kaimana_light_blue
rt_green <- kaimana_med_green
rt_orange <- coastside_orange
rt_teal <- rtemis_teal
rt_purple <- rtemis_purple
rt_magenta <- rtemis_light_magenta
highlight_col <- coastside_orange

col_object <- rt_green


#' rtemis Color System
#'
#' A named list of colors used consistently across all packages
#' in the rtemis ecosystem.
#'
#' Colors are provided as hex strings.
#'
#' @format A named list with the following elements:
#' \describe{
#'   \item{red}{"kaimana red"}
#'   \item{blue}{"kaimana light blue"}
#'   \item{green}{"kaimana medium green"}
#'   \item{orange}{"coastside orange"}
#'   \item{teal}{"rtemis teal"}
#'   \item{purple}{"rtemis purple"}
#'   \item{magenta}{"rtemis magenta"}
#'   \item{highlight_col}{"highlight color"}
#'   \item{object}{"rtemis teal"}
#'   \item{info}{"lmd burgundy"}
#'   \item{outer}{"kaimana red"}
#'   \item{tuner}{"coastside orange"}
#' }
#'
#' @author EDG
#'
#' @noRd
#'
#' @examples
#' rtemis_colors[["teal"]]
rtemis_colors <- list(
  red = kaimana_red,
  light_blue = kaimana_light_blue,
  blue = kaimana_blue,
  light_green = kaimana_green,
  green = kaimana_med_green,
  orange = coastside_orange,
  light_teal = rtemis_light_teal,
  teal = rtemis_teal,
  purple = rtemis_purple,
  light_magenta = rtemis_light_magenta,
  magenta = rtemis_magenta
)
