#load necessary packages
library(DatabaseConnector)
library(keyring)

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
