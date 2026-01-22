#generate a cohort according to the cohort_generator instructions before running 
#the following code
library(DatabaseConnector)
library(keyring)
library(dplyr)
library(ohdsilab)
  
#using ohdsilab::Vtable1 function to generate, view, and export table 1
my_table1 <- veradigm_table1(
  con,
  "cohort",
  veradigm_schema = "veradigm",
  write_schema = paste0(
    "work_",
    keyring::key_get("db_username")),
  min_count = 1)

View(my_table1)

write.csv(my_table1, "table1.csv", row.names = FALSE)