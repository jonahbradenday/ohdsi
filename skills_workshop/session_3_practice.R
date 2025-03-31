#1. Install the necessary packages. Because ohdsilab and ROhdsiWebApi have not 
#been added to CRAN, renv:install() is used instead of install.packages().
#remotes::install_github could also be used here.
renv::install(c("roux-ohdsi/ohdsilab","tidyverse", "DatabaseConnector", 
                "keyring", "OHDSI/RohdsiWebApi", "CohortGenerator", "gt"))

#2. Load the necessary packages.
library(ohdsilab)
library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(ROhdsiWebApi)
library(CohortGenerator)
library(gt)

#3. Set your database and ATLAS credentials. You credentials can be found in the 
#"Workspace Details" email you received after you created your workspace.
keyring::key_set("db_username")
keyring::key_set("db_password")
keyring::key_set("atlas_username")
keyring::key_set("atlas_password")


#4. Create the connection details and set path to JDBC driver. These details will be used as arguments in 
#later functions.
Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = "D:/Users/j.bradenday/Documents/jdbc_driver")

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password")
)

#5. Assign variables to the atlas url, the synpuf database schema and your 
#personal schema.
atlas_url <- "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
synpuf_schema <- "omop_cdm_synpuf_110k_531"
write_schema <- paste0("work_", keyring::key_get("db_username"))

#6. Connect to the database. You will do this again later, but for now you just 
#need the "con" information saved for the next step.
con <- DatabaseConnector::connect(connectionDetails)

#7. Make it easier for some r functions to find the database
options(con.default.value = con)
options(write_schema.default.value = write_schema)
options(schema.default.value = synpuf_schema)

#8. Connect to ATLAS.
ROhdsiWebApi::authorizeWebApi(
  atlas_url,
  authMethod = "db",
  webApiUsername = keyring::key_get("atlas_username"),
  webApiPassword = keyring::key_get("atlas_password")
)

#9. Identify the ATLAS cohort definition your want to use.
cohortId <- 4675


#10. Pull the cohort definition from ATLAS
cohortDefintionSet <- ROhdsiWebApi::exportCohortDefinitionSet(
  baseUrl = atlas_url,
  cohortIds = cohortId
)

#11. Set a naming convention for the cohort tables.
cohortTableNames <- CohortGenerator::getCohortTableNames(
  cohortTable = "cohort"
)


#12. Create empty tables in your personal schema using the naming convention
#designated in the last step.
CohortGenerator::createCohortTables(
  connectionDetails = connectionDetails,
  cohortDatabaseSchema = write_schema,
  cohortTableNames = cohortTableNames
)

#13. Generate your cohort for the Synpuf database.
CohortGenerator::generateCohortSet(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = synpuf_schema,
  cohortDatabaseSchema = write_schema,
  cohortTableNames = cohortTableNames,
  cohortDefinitionSet = cohortDefintionSet
)

#14. Connect to the database.
con <- DatabaseConnector::connect(connectionDetails)

#15. Because you reran "con" you will have to set the following option again.
options(con.default.value = con)

#16. Create a table containing your new cohort.
cohort <- tbl(con, inDatabaseSchema(write_schema, "cohort")) |>
  select(person_id = subject_id,
         cohort_start_date,
         cohort_end_date)

#17. How many people are in the cohort?
tally(cohort)

#18. Join your cohort to the person table to retrieve demographic information 
#and to the condition, drug, and concept tables to retrieve those data
demographics <- cohort |>
  omop_join("person", type = "inner", by = "person_id") |>
  select(
    person_id,
    cohort_start_date,
    cohort_end_date,
    gender = gender_source_value,
    year_of_birth) |>
  mutate(age_at_entry = year(cohort_start_date) - year_of_birth)

conditions <- cohort |>
  omop_join("condition_occurrence", type = "inner", by = "person_id") |>
  select(
    person_id,
    concept_id = condition_concept_id,
    concept_start_date = condition_start_date,
    concept_end_date = condition_end_date) |>
  mutate(domain = "condition")

drugs <- cohort |>
  omop_join("drug_exposure", type = "inner", by = "person_id") |>
  select(
    person_id,
    concept_id = drug_concept_id,
    concept_start_date = drug_exposure_start_date,
    concept_end_date = drug_exposure_end_date) |>
  mutate(domain = "drug")

cond_drug <- union_all(conditions, drugs) |>
  omop_join("concept", type = "inner", by = "concept_id")

#19. Create table showing all condition and drug events in chronological order
# and look at patient_id 6385's journey
patient_journey <- cond_drug |>
  arrange(concept_start_date, person_id)

patient_journey |>
  filter(person_id == 6385) |>
  gt()
#20. Create histogram of gender within age


