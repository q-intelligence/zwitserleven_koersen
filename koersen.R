# Zwitserleven fondskoersen ophalen en opslaan in CSV
# ------------------------------------------------------------------
# Bron   : https://www.zwitserleven.nl/en/about-zwitserleven/sustainability/funds/
# Uitvoer: data/koersen.csv  (volledige historie, 1 rij per fonds per koersdatum)
#          kolommen: fonds, slug, datum, jaar, koers, opgehaald_op
#          data/laatste.csv  (alleen de meest recente koersen)
#
# De pagina toont alleen de laatste koers. De historie bouw je op doordat dit
# script elke werkdag draait en nieuwe koersdata aan koersen.csv toevoegt.

suppressPackageStartupMessages({
  library(rvest)
  library(xml2)
  library(dplyr)
  library(stringr)
  library(readr)
})

URL        <- "https://www.zwitserleven.nl/en/about-zwitserleven/sustainability/funds/"
CSV_HISTORIE <- "data/koersen.csv"
CSV_LAATSTE  <- "data/laatste.csv"
MIN_FONDSEN  <- 30   # veiligheidscheck: minder rijen dan dit = waarschijnlijk iets stuk

# ------------------------------------------------------------------
# 1. Pagina ophalen en tabel uitlezen
# ------------------------------------------------------------------
haal_koersen_op <- function(url = URL) {
  pagina <- tryCatch(
    read_html(url),
    error = function(e) stop("Pagina ophalen mislukt: ", conditionMessage(e))
  )

  rijen <- html_elements(pagina, "table tbody tr")
  if (length(rijen) == 0) rijen <- html_elements(pagina, "table tr")
  if (length(rijen) == 0) stop("Geen tabelrijen gevonden. Is de paginastructuur gewijzigd?")

  uit <- lapply(rijen, function(rij) {
    cellen <- html_elements(rij, "td")
    if (length(cellen) < 3) return(NULL)

    link <- html_element(cellen[[1]], "a")
    href <- if (inherits(link, "xml_node")) html_attr(link, "href") else NA_character_

    tibble(
      fonds     = html_text2(cellen[[1]]),
      slug      = if (is.na(href)) NA_character_ else basename(sub("/+$", "", href)),
      datum_txt = html_text2(cellen[[2]]),
      koers_txt = html_text2(cellen[[3]])
    )
  })

  df <- bind_rows(uit)
  if (nrow(df) == 0) stop("Tabel gevonden, maar geen bruikbare rijen.")

  df %>%
    mutate(
      # zachte koppeltekens (U+00AD) en dubbele spaties uit fondsnamen halen
      fonds = str_squish(str_replace_all(fonds, "\u00AD", "")),
      datum = as.Date(datum_txt, format = "%d-%m-%Y"),
      # Engelse notatie op deze pagina: '€ 1,229.29' -> 1229.29
      jaar  = as.integer(format(datum, "%Y")),
      koers = as.numeric(str_replace_all(koers_txt, "[^0-9.]", "")),
      opgehaald_op = format(Sys.time(), tz = "UTC", usetz = TRUE)
    ) %>%
    filter(!is.na(datum), !is.na(koers)) %>%
    select(fonds, slug, datum, jaar, koers, opgehaald_op)
}

# ------------------------------------------------------------------
# 2. Samenvoegen met bestaande historie (zonder dubbelen)
# ------------------------------------------------------------------
voeg_samen <- function(nieuw, pad = CSV_HISTORIE) {
  if (file.exists(pad) && file.size(pad) > 0) {
    oud <- read_csv(
      pad,
      col_types = cols(
        fonds = col_character(), slug = col_character(),
        datum = col_date(format = "%Y-%m-%d"), koers = col_double(),
        opgehaald_op = col_character()
      ),
      show_col_types = FALSE
    )
    # bij dezelfde fonds+datum wint de nieuwste waarde
    alles <- bind_rows(oud, nieuw) %>%
      group_by(fonds, datum) %>%
      slice_tail(n = 1) %>%
      ungroup()
  } else {
    alles <- nieuw
  }

  # jaar altijd uit de datum afleiden, ook voor rijen uit een oud bestand
  # zonder jaar-kolom, en de kolomvolgorde vastleggen
  alles %>%
    mutate(jaar = as.integer(format(datum, "%Y"))) %>%
    select(fonds, slug, datum, jaar, koers, opgehaald_op) %>%
    arrange(fonds, datum)
}

# ------------------------------------------------------------------
# 3. Uitvoeren
# ------------------------------------------------------------------
main <- function() {
  dir.create("data", showWarnings = FALSE)

  nieuw <- haal_koersen_op()
  if (nrow(nieuw) < MIN_FONDSEN) {
    stop("Slechts ", nrow(nieuw), " fondsen gevonden (minimaal ", MIN_FONDSEN,
         " verwacht). Niets opgeslagen om de data niet te vervuilen.")
  }
  message(nrow(nieuw), " fondsen opgehaald; koersdatum: ",
          paste(format(unique(nieuw$datum), "%d-%m-%Y"), collapse = ", "))

  historie <- voeg_samen(nieuw)
  write_csv(historie, CSV_HISTORIE)

  laatste <- historie %>%
    group_by(fonds) %>%
    slice_max(datum, n = 1, with_ties = FALSE) %>%
    ungroup()
  write_csv(laatste, CSV_LAATSTE)

  message("Klaar. ", nrow(historie), " rijen in ", CSV_HISTORIE)
}

main()
