library(DatabaseConnector)
library(keyring)

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
