import os, unittest
import pkg/db_connector/db_postgres

import ../src/greskewel

var greskew: EmbeddedPostgres
test "can download, init, start, connect, query, and stop":
  # Initialize the embedded Postgres server with the default configuration.
  var greskew = initEmbeddedPostgres(
    PostgresConfig(
      basePath: getCurrentDir() / "tests" / "greskewelbox",
    )
  )

  # Download the Postgres binaries for the specified version
  # and store them in the configured path.
  greskew.downloadBinaries()