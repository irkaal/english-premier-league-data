suppressPackageStartupMessages({
  library(arrow)
  library(furrr)
  library(lubridate)
  library(parallel)
  library(rvest)
  library(tidyverse)
  library(usethis)
})

plan(multisession, workers = parallel::detectCores())

ui_info("Retrieving paths...")
url <- "https://www.football-data.co.uk/englandm.php"
paths <- read_html(url) |>
  html_nodes(css = "a:contains('Premier League')") |>
  html_attr("href") |>
  map_chr(~ str_c("https://www.football-data.co.uk/", .)) |>
  rev()
ui_done("OK")

ui_info("Retrieving results...")
read <- \(path) {
  suppressWarnings(
    read_csv(
      path,
      col_types = cols(
        .default = col_skip(),
        Div = col_skip(),
        Date = col_character(),
        Time = col_character(),
        HomeTeam = col_character(),
        AwayTeam = col_character(),
        FTHG = col_integer(),
        FTAG = col_integer(),
        FTR = col_character(),
        HTHG = col_integer(),
        HTAG = col_integer(),
        HTR = col_character(),
        Referee = col_character(),
        HS = col_integer(),
        AS = col_integer(),
        HST = col_integer(),
        AST = col_integer(),
        HC = col_integer(),
        AC = col_integer(),
        HF = col_integer(),
        AF = col_integer(),
        HY = col_integer(),
        AY = col_integer(),
        HR = col_integer(),
        AR = col_integer()
      )
    ) |>
      drop_na(Date) |>
      mutate(
        Season = str_sub(path, -11L, -10L) |>
          as_date(format = "%y") |>
          year() |>
          str_c("-", str_sub(path, -9L, -8L))
      )
  )
}
results <- future_map_dfr(paths, read, .progress = TRUE)
cat("\n")
ui_done("OK")

ui_info("Parsing dates...")
results <- results |>
  mutate(
    DateTime = Date |>
      str_c(replace_na(Time, ""), sep = " ") |>
      parse_date_time(c("dmy", "dmy HM"), tz = "GMT"),
    Date = NULL,
    Time = NULL
  ) |>
  select(Season, DateTime, everything())
ui_done("OK")

ui_info("Saving results...")
unlink("data", recursive = TRUE)
dir.create("data")
write_parquet(results, "data/results.parquet")
write_csv(results, "data/results.csv")
ui_done("OK")
