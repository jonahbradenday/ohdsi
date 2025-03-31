library(CohortExplorer)
library(DatabaseConnector)
library(keyring)
library(CohortGenerator)
library(ROhdsiWebApi)
library(CohortGenerator)

connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("db_username"),
                                             password = keyring::key_get("db_password"),
                                             pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")


atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))

con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

options(con.default.value = con)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)

ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = keyring::key_get("atlas_username"), 
                              webApiPassword = keyring::key_get("atlas_password"))

cohortId <- 4675

cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = cohortId)
cohortTableNames <- getCohortTableNames(cohortTable = "cohort")

createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = write_schema)

cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = synpuf_schema,
                                      cohortDatabaseSchema = write_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)


CohortExplorer::createCohortExplorerApp(
  connectionDetails = connectionDetails,
  cohortDatabaseSchema = write_schema,
  cdmDatabaseSchema = synpuf_schema,
  cohortTable = "cohort",
  cohortDefinitionId = cohortId,
  exportFolder = "D:/Users/j.bradenday/Documents/R Projects/ohdsi/cohortexplorer",
  databaseId = "redshift"
)

renv::install("lattice", "MASS", "Matrix", "mgcv", "nlme", "renv", "anytime", "askpass", "base64enc", "BH", "bslib", "cachem", "cli", "colorspace", "commonmark", "cpp11", "crayon", "crosstalk", "curl", "data.table", "digest", "dplyr", "ellipsis", "evaluate", "fansi", "farver", "fastmap", "fontawesome", "fs", "generics", "ggplot2", "glue", "gtable", "highr", "htmltools", "htmlwidgets", "httpuv", "httr", "isoband", "jquerylib", "jsonlite", "knitr", "labeling", "later", "lazyeval", "lifecycle", "magrittr", "memoise", "mime", "munsell", "openssl", "pillar", "pkgconfig", "plotly", "promises", "purrr", "R6", "rappdirs", "RColorBrewer", "Rcpp", "reactable", "reactR", "rlang", "rmarkdown", "sass", "scales", "shiny", "shinycssloaders", "shinyWidgets", "sourcetools", "stringi", "stringr", "sys", "tibble", "tidyr", "tidyselect", "tinytex", "utf8", "vctrs", "viridisLite", "withr", "xfun", "xtable", "yaml")

packages <- c("lattice", "MASS", "Matrix", "mgcv", "nlme", "renv", "anytime", "askpass", "base64enc", "BH", "bslib", "cachem", "cli", "colorspace", "commonmark", "cpp11", "crayon", "crosstalk", "curl", "data.table", "digest", "dplyr", "ellipsis", "evaluate", "fansi", "farver", "fastmap", "fontawesome", "fs", "generics", "ggplot2", "glue", "gtable", "highr", "htmltools", "htmlwidgets", "httpuv", "httr", "isoband", "jquerylib", "jsonlite", "knitr", "labeling", "later", "lazyeval", "lifecycle", "magrittr", "memoise", "mime", "munsell", "openssl", "pillar", "pkgconfig", "plotly", "promises", "purrr", "R6", "rappdirs", "RColorBrewer", "Rcpp", "reactable", "reactR", "rlang", "rmarkdown", "sass", "scales", "shiny", "shinycssloaders", "shinyWidgets", "sourcetools", "stringi", "stringr", "sys", "tibble", "tidyr", "tidyselect", "tinytex", "utf8", "vctrs", "viridisLite", "withr", "xfun", "xtable", "yaml")

lapply(packages, library, character.only = TRUE)