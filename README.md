# clickhouse-backup.sh

Backup / restore _small_ [ClickHouse](https://clickhouse.tech/) databases.

For bigger databases, please see [clickhouse-backup](https://github.com/AlexAkulov/clickhouse-backup).

## Install

```sh
sudo wget -O /usr/local/bin/clickhouse-backup.sh \
  https://raw.githubusercontent.com/mahadana/clickhouse-backup.sh/main/clickhouse-backup.sh
sudo chmod a+x /usr/local/bin/clickhouse-backup.sh
```

## Usage

```
clickhouse-backup.sh -d dbname backup > dumpfile

clickhouse-backup.sh -d dbname restore < dumpfile

clickhouse --help
```
