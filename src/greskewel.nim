# Postgres in a Box. For Nim 
#
# This package provides an easy way to run an embedded Postgres server
# for testing and development purposes. It allows you to start, stop,
# and manage a Postgres server instance without needing to install it
# 
# Mainly inspired by https://github.com/fergusstrange/embedded-postgres
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/postgresbox

import std/[tables, times, os, osproc, strutils, net]
import pkg/threading/channels

type
  PostgresVersion* = enum
    v18 = "18.0.0"
    v17 = "17.5.0"
    v16 = "16.9.0"
    v15 = "15.13.0"
    v14 = "14.18.0"
    v13 = "13.21.0"

    # https://github.com/fergusstrange/embedded-postgres/blob/master/config.go#L11

  PostgresConfig* = ref object
    version: PostgresVersion = PostgresVersion.v16
      # The version of Postgres to use. You can specify a specific
      # version like "16.4.0" or use a predefined version
      # from the PostgresVersion enum.
    port*: Port = Port(5432)
      # Default port for Postgres is 5432, but you
      # can specify a different one if needed.
    database: string = "postgres"
      # Name of the default database to create when Postgres starts.
    username: string = "postgres"
      # Username for the default database. Default is "postgres".
    password: string = "postgres"
      # Password for the default database user. Default is "postgres".
    basePath*: string
      # Base path for all Postgres-related files. This is the root
      # directory under which all other paths (cache, runtime, data, binaries)
      # will be organized.
    cachePath*: string = "cache"
      # Path to cache downloaded Postgres binaries.
      # Ensure this directory is writable.
    runtimePath*: string = "runtime"
      # Path to store runtime files like logs and sockets.
      # Ensure this directory is writable.
    dataPath*: string = "data"
      # Path to store Postgres data. Ensure this directory
      # is writable and has enough space.
    binariesPath*: string = "bin"
      # Path to the Postgres binaries. This should point
      # to the directory containing the Postgres executables.
    locale: string
      # Locale settings for the Postgres cluster. Default is "en_US.UTF-8".
    startParameters: Table[string, string]
      # Additional parameters to pass when starting Postgres,
      # such as shared_buffers, max_connections, etc.
    binaryRepositoryURL: string = "https://repo1.maven.org/maven2/"
      # URL to download Postgres binaries. Default is the Maven Central repository.
    startTimeout: Duration
      # Timeout for starting the Postgres server. Default is 30 seconds.
    # logger: string # todo

  EmbeddedPostgres* = object
    config: PostgresConfig
    started: bool

  GreskewelConfigError* = object of CatchableError

var greskewChan = newChan[string]()

proc initEmbeddedPostgres*(config: PostgresConfig = nil,
            version: PostgresVersion = PostgresVersion.v16): EmbeddedPostgres =
  ## Initializes the embedded Postgres server with the specified configuration.
  ## If no configuration is provided, it uses the default configuration for the specified version.
  result = EmbeddedPostgres(
    config:
      if config != nil: config
      else: PostgresConfig(version: version)
  )
  if result.config.binaryRepositoryURL.len == 0:
    result.config.binaryRepositoryURL = "https://repo1.maven.org/maven2/"

#
# Remote Controls
#
const
  binariesEndpoint = "io/zonky/test/postgres/embedded-postgres-binaries-$1-$2/$3/"
  jarBinaryEndpoint = "embedded-postgres-binaries-$1-$2-$3.jar"
  getCurrentOS* = 
    when defined macosx: "darwin"
    else: system.hostOS
  binInitAppPath = "$1/$2/initdb" % [getCurrentOS, "bin"]
    # Note: The actual paths to the Postgres binaries may vary based on the version and platform.
  binPgCtlAppPath = "$1/$2/pg_ctl" % [getCurrentOS, "bin"]
    # Note: The actual paths to the Postgres binaries may vary based on the version and platform.

template ensureDirs() =
  if ep.config.basePath.len == 0 or ep.config.basePath.isAbsolute == false:
    raise newException(GreskewelConfigError,
      "Base path must be specified and absolute in the configuration.")
  if ep.config.dataPath.len == 0:
    raise newException(GreskewelConfigError,
      "Data path must be specified in the configuration.")
  if ep.config.binariesPath.len == 0:
    raise newException(GreskewelConfigError,
      "Binaries path must be specified in the configuration.")
  
  discard existsOrCreateDir(ep.config.basePath)
  discard existsOrCreateDir(ep.config.basePath / ep.config.runtimePath)
  discard existsOrCreateDir(ep.config.basePath / ep.config.binariesPath)

proc downloadBinaries*(ep: var EmbeddedPostgres) =
  ## Download the Postgres binaries for the specified version and store them in the configured path.
  ensureDirs()
  let jarFile = jarBinaryEndpoint % [getCurrentOS, hostCPU, $ep.config.version]
  let jarUrl = ep.config.binaryRepositoryURL & (binariesEndpoint % [getCurrentOS, hostCPU, $ep.config.version]) & jarFile
  
  # Download the jar file containing the Postgres binaries if it doesn't already exist
  if not fileExists(ep.config.basePath / ep.config.binariesPath / jarFile):
    echo "Downloading Postgres binaries from:\n", jarUrl
    echo execCmdEx("curl -L -o " & ep.config.basePath / ep.config.binariesPath / jarFile & " " & jarUrl)

  # unzip the jar file to extract the binaries
  createDir(ep.config.basePath / ep.config.binariesPath / $ep.config.version)
  let unzipPath = ep.config.basePath / ep.config.binariesPath / $ep.config.version / getCurrentOS
  if fileExists(ep.config.basePath / ep.config.binariesPath / jarFile) and not dirExists(unzipPath):
    echo "Unzipping Postgres binaries to:\n", unzipPath
    echo execCmdEx("unzip " & ep.config.basePath / ep.config.binariesPath / jarFile & " -d " & unzipPath)

  # extract the tar file to get the actual binaries
  let tarPath = unzipPath / "postgres-" & getCurrentOS & "-x86_64.txz"
  let isExtracted = dirExists(unzipPath / "bin") and dirExists(unzipPath / "lib")
  if fileExists(tarPath) and not isExtracted:
    echo "Extracting Postgres binaries from:\n", tarPath
    let status = execCmdEx("tar -xvf " & tarPath & " -C \"" & unzipPath & "\"")
    if status.exitCode != 0:
      raise newException(GreskewelConfigError, "Failed to extract Postgres binaries: " & status.output)
  
#
# Postgres Controls
#
proc encodeOptions(port: Port, parameters: Table[string, string]): string =
  var options = @["-p " & $port]
  for k, v in parameters:
    options.add("-c " & k & "=\"" & v & "\"")
  result = options.join(" ")

proc init*(ep: var EmbeddedPostgres) =
  ## Initialize the embedded Postgres server with the specified configuration.
  echo "Initializing embedded Postgres version ", $ep.config.version
  ensureDirs()
  let dataPath = ep.config.basePath / ep.config.dataPath
  # Initialize the Postgres data directory using the `initdb` binary 
  let initDbApp = ep.config.basePath / ep.config.binariesPath / $ep.config.version / binInitAppPath
  if not initDbApp.fileExists():
    raise newException(GreskewelConfigError,
      "`initdb` binary not found at expected path: " & initDbApp)
  let res = execCmdEx(initDbApp & " -D " & dataPath & " --username postgres")
  if res.exitCode != 0:
    raise newException(GreskewelConfigError,
      "Failed to initialize Postgres data directory: " & res.output)
  
type
  PostgresThreadInfo = tuple
    channel: ptr Chan[string]
    dataPath: string
    binPath: string
    port: Port

proc postgresThread(pg: PostgresThreadInfo) {.thread.} =
  # this thread will run a loop to listen for commands to start/stop the Postgres server
  var pgProc: Process
  var isRunning = false
  while true:
    var command: string
    if pg[0][].tryRecv(command):
      let pidPath = pg[1] / "postmaster.pid"
      if command == "pg.start":
        if not pidPath.fileExists():
          let encodedOpts = encodeOptions(pg[3], initTable[string, string]())
          let pgProc = startProcess(pg.binPath / binPgCtlAppPath,
                      args = ["start", "-w", "-D", pg[1], "-o", encodedOpts])
      elif command == "pg.stop" and pidPath.fileExists():
        let res = execCmdEx(pg.binPath / binPgCtlAppPath & " stop -w -D " & pg[1])
        # echo res 
    sleep(100) # small delay to prevent busy waiting

var worker: Thread[PostgresThreadInfo]
proc start*(ep: var EmbeddedPostgres) =
  ## Start the embedded Postgres server
  let currentBinPath = ep.config.basePath / ep.config.binariesPath / $ep.config.version
  let dataPath = ep.config.basePath / ep.config.dataPath
  createThread(worker, postgresThread, (addr(greskewChan), dataPath, currentBinPath, ep.config.port))
  sleep(1000) # wait a bit for the server to start
  greskewChan.send("pg.start")
  sleep(2000) # wait a bit for the server to start
  ep.started = true # todo: this should be set based on the actual status of the server, not just after sending the start command

proc stop*(ep: var EmbeddedPostgres) =
  ## Stop the embedded Postgres server
  greskewChan.send("pg.stop")
  sleep(5000) # wait a bit for the server to stop before exiting 

proc restart*(ep: var EmbeddedPostgres) =
  ## Restart the embedded Postgres server
  stop(ep)
  start(ep)

proc dispose*(ep: var EmbeddedPostgres) =
  ## Dispose of the data directory and any resources used by the embedded Postgres server.
  let dataPath = ep.config.basePath / ep.config.dataPath
  if dataPath.dirExists and fileExists(dataPath / "postmaster.pid") == false:
    removeDir(dataPath)

proc status*(ep: EmbeddedPostgres): string =
  ## Get the status of the embedded Postgres server
  let cmd = @["pg_ctl", "status", "-D", ep.config.dataPath]
  result = staticExec(cmd.join(" "))

proc isRunning*(ep: EmbeddedPostgres): bool =
  ## Check if the embedded Postgres server is running
  result = ep.started

proc getConnectionString*(ep: EmbeddedPostgres): string =
  ## Get the connection string for the embedded Postgres server
  result = "postgresql://" & ep.config.username & ":" & ep.config.password &
           "@localhost:" & $ep.config.port & "/" & ep.config.database

proc getVersion*(ep: EmbeddedPostgres): PostgresVersion =
  ## Get the version of the embedded Postgres server
  result = ep.config.version

proc getConfig*(ep: EmbeddedPostgres): PostgresConfig =
  ## Get the configuration of the embedded Postgres server
  result = ep.config
