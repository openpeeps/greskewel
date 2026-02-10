import os, unittest

{.passL: "-Wl,-rpath," & currentSourcePath().parentDir / "greskewelbox" / "bin" / "16.9.0" / "darwin" / "lib".}
# {.passL: currentSourcePath().parentDir / "greskewelbox" / "bin" / "16.9.0" / "darwin" / "lib" / "libpq.dylib".}
import pkg/db_connector/db_postgres
import ../src/greskewel

var greskew: EmbeddedPostgres
test "can init, start, connect, query, and stop":
  # Initialize the embedded Postgres server with the default configuration.
  var greskew = initEmbeddedPostgres(
    PostgresConfig(
      basePath: getCurrentDir() / "tests" / "greskewelbox",
    )
  )

  # Download the Postgres binaries for the specified version
  # and store them in the configured path.
  # greskew.downloadBinaries()

  # Initialize the Postgres server
  # This will set up the data directory and prepare
  # the server for starting. 
  greskew.init()

  # Start the Postgres server
  # This proc will run in a separate thread
  # to avoid blocking the main thread.
  greskew.start()
  
  {.push dynlib: currentSourcePath().parentDir / "greskewelbox" / "bin" / "16.9.0" / "darwin" / "lib" / "libpq.dylib".}
  let db = open("localhost", "postgres", "postgres", "postgres")
  db.exec(sql"""CREATE TABLE myTable (id integer, name varchar(50) not null)""")
  db.exec(sql"""INSERT INTO myTable (id, name) VALUES (1, 'Alice')""")
  for row in db.getAllRows(sql"""SELECT * FROM myTable"""):
    echo "Row: ", row
  {.pop.}

  # Stop the Postgres server
  greskew.stop()

  # Dispose of the data directory and any resources
  # used by the embedded Postgres server.
  greskew.dispose()
