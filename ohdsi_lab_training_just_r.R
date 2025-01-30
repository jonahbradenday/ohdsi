#1. Install the necessary packages. 
#If you have already installed the following packages, skip to step 2. 
renv::upgrade()
renv::install(c("roux-ohdsi/ohdsilab","tidyverse", "DatabaseConnector", 
                "keyring", "CohortGenerator"))

#2. Load the necessary packages.
library(ohdsilab)
library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(CohortGenerator)

#3. Set your database credentials.
#When you run each of the following four lines of code, a popup will appear, 
#asking for you to input the credential. 
#Your credentials can be found in the OHDSI Lab workspace email you received 
#after creating your workspace.
keyring::key_set("db_username")
keyring::key_set("db_password")

#4. Create the connection
con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver"
)

#5. Assign the schema information to easy-to-reference variables.
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))

#6. Make it easier for some r functions to find the database
options(con.default.value = con)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)

#Filter for entry event
entry_event <- tbl(con, inDatabaseSchema(synpuf_schema, 
                                         "condition_occurrence")) |>
  filter(condition_concept_id %in% c(45766052,4193704,3191208,3193274,36684827,
                                     3192767,4129519,4099651,4063043,201826,
                                     4230254,43531010,4130162,3194332,3194082,
                                     45757474,4304377)) |>
  select(person_id, entry_date = condition_start_date)

#Filter for inclusion criteria
inclusion_criteria <- tbl(con, inDatabaseSchema(synpuf_schema,
                                                 "drug_exposure")) |>
  filter(drug_concept_id == 40164929) |>
  select(person_id, inclusion_date = drug_exposure_start_date)

#create table for observation period
observation_period <-(tbl(con, inDatabaseSchema(synpuf_schema, 
                                                "observation_period")))

#Filter for both entry event and inclusion criteria and add cohort end date
cohort <- entry_event |>
  inner_join(inclusion_criteria, by = "person_id") |>
  filter(inclusion_date >= entry_date, 
         inclusion_date <= dbplyr::sql("DATEADD(day, 30, entry_date)")) |>
  select(person_id, cohort_start_date = entry_date) |>
  inner_join(observation_period, by = "person_id") |>
  select(person_id, cohort_start_date, 
         cohort_end_date = observation_period_end_date) |>
  group_by(person_id) |>
  summarise(cohort_start_date = min(cohort_start_date),
    cohort_end_date = max(cohort_end_date)) |>
  ungroup()
