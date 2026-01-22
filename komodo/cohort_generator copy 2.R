library(DatabaseConnector)
library(keyring)
library(dplyr)

key_set("db_username")
key_set("db_password")

connectionDetails <- createConnectionDetails(
  dbms = "postgresql",
  server = "localhost/postgres",
  port = 5433,
  user = key_get("db_username"),
  password = key_get("db_password"),
  pathToDriver = "/Users/j.bradenday/Documents/programming/driver"
)

con <- connect(connectionDetails)

synthea_schema <- "public"
write_schema <- "scratch"


executeSql(con, "
           CREATE TABLE scratch.cohort2 AS
           SELECT DISTINCT c.patient, c.start AS cohort_start_date
           FROM public.conditions c
           INNER Join public.medications m
            ON c.patient = m.patient
           WHERE c.code = '40055000'
            AND m.code = '309362'
            AND m.start > '2001-11-05'
           ")

cohort <- tbl(
  con,
  inDatabaseSchema(write_schema, "cohort1")) |>
  select(patient, cohort_start_date)

patients <- tbl(
  con,
  inDatabaseSchema(synthea_schema, "patients"))

demographics <- cohort |> 
  inner_join(patients, by = c("patient" = "id")) |> 
  select(patient, cohort_start_date, birthdate, race, gender, city) |> 
  mutate(age_at_entry = year(cohort_start_date) - year(birthdate))

conditions <- tbl(
  con,
  inDatabaseSchema(synthea_schema, "conditions")
)

condition_history <- cohort |>
  inner_join(conditions, by = "patient") |>
  select(patient, cohort_start_date, code, description, start)

