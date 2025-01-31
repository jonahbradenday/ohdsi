#1. Install the necessary packages. Because ohdsilab has not been added to CRAN,
#renv:install() is used instead of install.packages()
renv::upgrade()
renv::install(c("roux-ohdsi/ohdsilab","tidyverse", "DatabaseConnector", 
                "keyring", "CohortGenerator"))

#2. Load the necessary packages.
library(ohdsilab)
library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(CohortGenerator)

#3. Set your database credentials. You credentials can be found in the 
#"Workspace Details" email you received after you created your workspace.
keyring::key_set("db_username")
keyring::key_set("db_password")

#4. Connect to the database.
con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

#5. Assign variables to the synpuf database schema and your personal schema.
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))

#6. Make it easier for some r functions to find the database
options(con.default.value = con)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)

#7. #The human readable description of the cohort designed here can be found in 
#cohort_description.rmd.Filter the synpuf data for the entry event.
entry_event <- tbl(con, inDatabaseSchema(synpuf_schema, 
                                         "condition_occurrence")) |>
  filter(condition_concept_id %in% c(45766052,4193704,3191208,3193274,36684827,
                                     3192767,4129519,4099651,4063043,201826,
                                     4230254,43531010,4130162,3194332,3194082,
                                     45757474,4304377)) |>
  select(person_id, entry_date = condition_start_date)

#8. Filter the synpuf data for inclusion criteria. If more inclusion criteria are
#needed, use naming scheme inclusion_criteria_1, inclusion_criteria_2, etc.
inclusion_criteria <- tbl(con, inDatabaseSchema(synpuf_schema,
                                                 "drug_exposure")) |>
  filter(drug_concept_id == 40164929) |>
  select(person_id, inclusion_date = drug_exposure_start_date)

#9. Create a table for observation period. This specific cohort definition uses 
#observation_period_end_date as the cohort_end_date for each person included.
observation_period <-(tbl(con, inDatabaseSchema(synpuf_schema, 
                                                "observation_period")))

#10. Join entry_event with inclusion_criteria, filtering for  rows that 
#satisfy date inclusion criteria
cohort_r <- entry_event |>
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

#11. After running the above code, your cohort should be nearly identical to the 
#one generated using ATLAS in "ohdsi_lab_training_r_and_ATLAS.R" You can check 
#by running the comparing the output of the following tally with the output of 
#step 15 in "ohdsi_lab_training_r_and_ATLAS.R".
tally(cohort_r)
