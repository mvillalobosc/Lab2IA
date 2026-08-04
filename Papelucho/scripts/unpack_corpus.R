# =============================================================================
# unpack_corpus.R
# -----------------------------------------------------------------------------
# EN: Unpacks data/raw/corpus.tar.gz into data/raw/papelucho and
#     data/raw/comparison, then verifies every file against the checksums in
#     data/metadata/corpus_checksums.csv.
#
#     The verification is the point. Two people can only reproduce the same
#     numbers if they are analysing byte-identical texts, and text files silently
#     change through re-encoding, line-ending conversion or an editor adding a
#     trailing newline. A checksum mismatch is reported per file so the culprit
#     is obvious.
#
#     If corpus.tar.gz is absent because the corpus was not redistributed, this
#     script still runs: it verifies whatever files are already in place and
#     reports which of the 75 are missing.
#
#         Rscript scripts/unpack_corpus.R
#
# ES: Descomprime data/raw/corpus.tar.gz en data/raw/papelucho y
#     data/raw/comparison, y despues verifica cada archivo contra los checksums
#     de data/metadata/corpus_checksums.csv.
#
#     La verificacion es el punto. Dos personas solo pueden reproducir los mismos
#     numeros si analizan textos identicos byte a byte, y los archivos de texto
#     cambian en silencio por recodificacion, conversion de fin de linea o un
#     editor que agrega un salto final. Una discrepancia de checksum se reporta
#     por archivo para que el culpable sea obvio.
#
#     Si corpus.tar.gz no esta porque el corpus no se redistribuyo, este script
#     igual corre: verifica los archivos que ya esten en su lugar y reporta
#     cuales de los 75 faltan.
# =============================================================================

archive   <- file.path("data", "raw", "corpus.tar.gz")
checksums <- file.path("data", "metadata", "corpus_checksums.csv")

if (!file.exists(checksums)) {
  stop("Checksum file not found: ", checksums, call. = FALSE)
}

if (file.exists(archive)) {
  message("Unpacking ", archive, " ...")
  utils::untar(archive, exdir = file.path("data", "raw"))
} else {
  message("No corpus archive at ", archive,
          ".\nVerifying whatever text files are already in place.")
}

cs <- utils::read.csv(checksums, stringsAsFactors = FALSE)

cs$path <- ifelse(
  cs$group == "Papelucho",
  file.path("data", "raw", "papelucho",  cs$filename),
  file.path("data", "raw", "comparison", cs$filename)
)

cs$present <- file.exists(cs$path)
cs$actual  <- NA_character_
cs$actual[cs$present] <- vapply(
  cs$path[cs$present],
  function(p) unname(as.character(tools::md5sum(p))),
  character(1)
)
cs$ok <- cs$present & !is.na(cs$actual) & cs$actual == cs$md5

n_missing  <- sum(!cs$present)
n_mismatch <- sum(cs$present & !cs$ok)

message("\n", sum(cs$ok), " of ", nrow(cs), " files verified.")

if (n_missing > 0) {
  message("\nMISSING (", n_missing, "):")
  for (f in cs$filename[!cs$present]) message("  ", f)
  message("\nSee docs/CORPUS.md for how to reconstruct the corpus.")
}

if (n_mismatch > 0) {
  message("\nCHECKSUM MISMATCH (", n_mismatch, "):")
  bad <- cs[cs$present & !cs$ok, ]
  for (i in seq_len(nrow(bad))) {
    message("  ", bad$filename[i],
            "  expected ", substr(bad$md5[i], 1, 12),
            "  got ", substr(bad$actual[i], 1, 12))
  }
  message("\nThese files differ from the ones the published results were computed on.",
          "\nThe usual cause is a re-encoding or a line-ending conversion.")
}

if (n_missing == 0 && n_mismatch == 0) {
  message("Corpus is complete and byte-identical to the published version.")
} else {
  quit(status = 1)
}
