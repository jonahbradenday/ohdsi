#1. Install the necessary packages. 
#If you have already installed the following packages, skip to step 2. 
renv::upgrade()
renv::install(c("roux-ohdsi/ohdsilab","tidyverse", "DatabaseConnector", 
                "keyring", "OHDSI/RohdsiWebApi", "CohortGenerator"))

#2. Load the necessary packages.
library(ohdsilab)
library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(ROhdsiWebApi)
library(CohortGenerator)

#3. Set your database and ATLAS login credentials.
#When you run each of the following four lines of code, a popup will appear, 
#asking for you to input the credential. 
#Your credentials can be found in the OHDSI Lab workspace email you received 
#after creating your workspace.
keyring::key_set("db_username")
keyring::key_set("db_password")
keyring::key_set("atlas_username")
keyring::key_set("atlas_password")

#4. Create the connection details
connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("db_username"),
                                             password = keyring::key_get("db_password"),
                                             pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

#5. Assign the schema and atlas information to easy-to-reference variables.
atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))

#6. Make it easier for some r functions to find the database
options(con.default.value = con)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)


#7. Connect to ATLAS
ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = keyring::key_get("atlas_username"), 
                              webApiPassword = keyring::key_get("atlas_password"))

#8. Identify the ATLAS cohort definition your want to use.
cohortId <- 4675

#9. Pull the cohort definition from ATLAS
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = cohortId)
#10. Name your cohort
cohortTableNames <- getCohortTableNames(cohortTable = "synpuf4675")

#11. Create empty tables in the white_schema cohort table
createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = write_schema)

#12. Add everyone who fits cohort definition in synpuf to cohort table
cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = synpuf_schema,
                                      cohortDatabaseSchema = write_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)

#13. Connect to the database
con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

#14. Filter person table for only the people in your cohort
#14.1 pull data from your new cohort table
cohort <- tbl(con, inDatabaseSchema(write_schema, "synpuf4669")) |>
  select(person_id = subject_id, cohort_start_date, cohort_end_date)

#14.2 join to the person table to get information about demographics, calculate age 
#at cohort entry
demographics <- cohort |> 
  omop_join("person", type = "inner", by = "person_id") |> 
  select(person_id, cohort_start_date, cohort_end_date, year_of_birth, 
         gender = gender_concept_id, race = race_concept_id, 
         ethnicity = ethnicity_concept_id) |> 
  mutate(age_at_entry = year(cohort_start_date) - year_of_birth)

#15. join to the drug_exposure table to get information about drugs
drugs <- demographics |>
  omop_join("drug_exposure", type = "left", by = "person_id") |>
  select(person_id, year_of_birth, gender, race, ethnicity, 
         concept_id = drug_concept_id, drug_exposure_start_date, 
         drug_exposure_end_date)

#16. join to the concept table to get human readable drug names
drugs <- drugs |>
  omop_join("concept", type = "left", by = "concept_id") |>
  select(person_id, year_of_birth, gender, race, ethnicity, 
         concept_id, drug = concept_name, 
         drug_exposure_start_date, drug_exposure_end_date)

#17. Collect your joined table into a dataframe
drugs_df <- drugs |> dbi_collect()

#18. Replace gender, race, and ethnicity values with human readable values
drugs_df <- drugs_df %>%
  mutate(gender = case_when(gender == 8507 ~ "Male",
                            gender == 8532 ~ "Female"),
         race = case_when(race == 0 ~ NA,
                          race == 8516 ~ "Black",
                          race == 8527 ~ "White"),
         ethnicity = case_when(ethnicity == 38003563 ~ "Hispanic or Latino",
                               ethnicity == 38003564 ~ "Not Hispanic or Latino"))

#19. Calculate prevalence rates of each drug
drug_prevalence <- drugs_df %>%
  count(drug) %>%         
  mutate(prop = prop.table(n))

#20. How many drugs per person per gender?
avg_drugs_by_gender <- drugs_df %>%
  group_by(gender, person_id) %>%
  summarise(num_drugs = n(), .groups = "drop") %>%
  group_by(gender) %>%
  summarise(avg_drugs = mean(num_drugs), .groups = "drop")

#21. How did drug exposure change over time?
drugs_per_date <- drugs_df %>%
  group_by(drug_exposure_start_date) %>%
  summarize(person_count = n_distinct(person_id))

ggplot(drugs_per_date) +
  geom_line(aes(x = drug_exposure_start_date, y = person_count))

#22 What percentage of each race has been prescribed drug x:
#Metformin hydrochloride 500 MG Oral Tablet (e.g., white drug x users/white total)
total_persons <- n_distinct(drugs_df$person_id)

metformin_users <- drugs_df %>%
  filter(drug == "Metformin hydrochloride 500 MG Oral Tablet") %>%
  group_by(race) %>%
  summarize(person_count = n_distinct(person_id), .groups = "drop") %>%
  mutate(proportion = person_count/total_persons)

ggplot(metformin_users) +
  geom_bar(aes(x = race, y = proportion, fill = race), stat = "identity") +
  labs(x = "Race", y = "Percentage of Race", 
       title = "Proportion of Each Race Taking Metformin")
