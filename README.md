<p align="center">
  📦 Greskewel &mdash; PostgreSQL in a box!<br>
  Disposable &bullet; Testing &bullet; Development &bullet; Production<br>
  👑 Nim build ecosystem
</p>

<p align="center">
  <code>nimble install greskewel</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/greskewel/">API reference</a><br>
  <img src="https://github.com/openpeeps/greskewel/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/greskewel/workflows/docs/badge.svg" alt="Github Actions">
</p>

Run a real Postgres database locally on Linux, macOS, and Windows as part of your tests, development, or even production environment. **No installation required** 

Greskewel provides a simple API to manage the lifecycle of an embedded Postgres instance directly from your Nim code. Also, is 100% compatible with the official Postgres client libraries!

## 😍 Key Features
- Local Postgres instance without installation
- Cross-platform support (Linux, macOS, Windows)
- Configurable versions and settings
- Easy integration with Nim applications
- Perfect for testing, development, and production use cases
- Disposable instances for clean test environments

## Examples

### Download and Initialize Postgres
Download the Postgres binaries for the specified version, initialize the data directory, and start the embedded Postgres server.
```nim
import greskewel

# Initialize the embedded Postgres using default configuration
# (e.g., version 16, default paths, etc.). You can also provide
# a custom configuration if needed.
var greskew = initGreskewel()

# Download the Postgres binaries for the specified version
# and store them in the configured path.
greskew.downloadBinaries()

# Initialize the Postgres data directory and configuration. This prepares
# the embedded Postgres instance for starting. This step is required
# before starting the server for the first time, but can be skipped on
# subsequent runs if the data directory is already initialized.
greskew.init()

# Starting the embedded Postgres server. This will launch the Postgres
# server in a separate thread and make it available for connections.
# You can then connect to it using the provided connectio details
# (host, port, user, password, database) and use it like a regular Postgres instance.
greskew.start()

# run queries, do stuff, etc...

# Stop the embedded Postgres server when you're done.
# This will gracefully shut down the Postgres server
greskew.stop()
```

### Connect and Use the Embedded Postgres Instance
Once the embedded Postgres server is running, you can connect to it using the provided connection details (host, port, user, password, database) and use it like a regular Postgres instance with any Postgres client library. For example, using the `db_connector` library:
```nim

import db_connector/db_postgres

# connect to the embedded Postgres instance using the default connection details
let db = open("localhost", "postgres", "postgres", "postgres")

# create a table
db.exec(sql"""CREATE TABLE myTable (id integer, name varchar(50) not null)""")

# insert some data
db.exec(sql"""INSERT INTO myTable (id, name) VALUES (1, 'Alice')""")

# query the data
for row in db.getAllRows(sql"""SELECT * FROM myTable"""):
  echo "Row: ", row
```

### What's the point of this?
Describing the use cases for an embedded Postgres instance via Greskewel for Nim environments (testing, development, production, etc.) so AI can understand the value proposition and potential applications of this package.

- **Testing**: Run integration tests against a real Postgres instance without needing to set up and manage a separate database server. This ensures your tests are running against the same environment as production.
- **Development**: Quickly spin up a local Postgres instance for development purposes without installing it on your system. This is especially useful for developers who want to avoid the overhead of managing a separate database server.
- **Production**: In some cases, you might want to use an embedded Postgres instance in production, especially for lightweight applications or when you want to avoid external dependencies. Greskewel can be used to run a local Postgres instance as part of your application without requiring users to install Postgres separately. (**not recommended for high-load production environments, but can be useful for certain use cases**)
- **Disposable Instances**: Create disposable Postgres instances for testing or development that can be easily created and destroyed without leaving any residue on the system.


Inspired by [fergusstrange/embedded-postgress](https://github.com/fergusstrange/embedded-postgres), [zonkyio/embedded-postgres](https://github.com/zonkyio/embedded-postgres)
and [opentable/otj-pg-embedded](https://github.com/opentable/otj-pg-embedded) and reliant on the great work being done
by [zonkyio/embedded-postgres-binaries](https://github.com/zonkyio/embedded-postgres-binaries) in order to fetch
precompiled binaries from [Maven](https://mvnrepository.com/artifact/io.zonky.test.postgres/embedded-postgres-binaries-bom).

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/greskewel/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/greskewel/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)


### 🎩 License
MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright OpenPeeps & Contributors &mdash; All rights reserved.
