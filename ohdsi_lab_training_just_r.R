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
  pathToDriver = "D:/Users/j.bradenday/Documents/R_projects/pmtx_connection_test/jdbc/redshift-jdbc42-2.1.0.32"
)

#5. Make it easier for some r functions to find the database
options(con.default.value = con)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)

#6. Assign the schema and atlas information to easy-to-reference variables.
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))