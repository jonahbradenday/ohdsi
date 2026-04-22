#load necessary packages
library(DatabaseConnector)
library(keyring)
library(dplyr)
library(lubridate)
library(ohdsilab)

#set database credentials
key_set("db_username")
key_set("db_password")

#point R to JDBC driver you installed on your workspace
Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = "insert path to jdbc driver here")

#set database connection details
connectionDetails <- createConnectionDetails(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"))

#connect to database
con <- connect(connectionDetails)

#set dataset and write schemas
komodo_schema <- "komodo"
write_schema <- paste0(
  "work_",
  keyring::key_get("db_username"))

#the next steps will illustrate the process of creating a cohort of patients who 
# have been diagnosed with type 2 diabetes, prescribed metformin within one month
# after their type 2 diabetes diagnosis, and undergone metabolic surgery within 6 
# months after their type 2 diabetes diagnosis

#get patient ids and diagnosis dates for all type 2 diabetes episodes (using the 
# ICD-10 code E11 and all its descendants).
t2d_events <- ohdsilab::k_get_condition_events(
  con,
  codes = c("E11.%"))

#get patient ids and procedure dates for all metabolic surgery episodes (using 
# the CPT codes 43644 and 43775)
metabolic_surgery_events <- ohdsilab::k_get_procedure_events(
  con,
  codes = c("43644", "43775"))

#load the the pharmacy table and filter for metformin events
metformin_events <- tbl(con, inDatabaseSchema(komodo_schema, "pharmacy_events")) |>
  filter(generic_name == "metformin") |>
  select(patient_id, service_date)
  
#create a cohort using combining data from the above lazy tables
t2d_cohort <- t2d_events |>
  group_by(patient_id) |>
  summarize(index_date = min(diagnosis_date)) |>
  inner_join(metformin_events, by = "patient_id") |>
  filter(service_date >= index_date,
         service_date <= index_date + lubridate::days(30)) |>
  distinct(patient_id, index_date) |>
  inner_join(metabolic_surgery_events, by = "patient_id") |>
  filter(procedure_date >= index_date,
         procedure_date <= index_date + lubridate::days(180)) |>
  distinct(patient_id, index_date)

#save cohort to a table in your write_schema
DatabaseConnector::executeSql(con, paste0(
  "DROP TABLE IF EXISTS ", write_schema, ".t2d_cohort;
   CREATE TABLE ", write_schema, ".t2d_cohort AS ",
  dbplyr::sql_render(t2d_cohort)
))