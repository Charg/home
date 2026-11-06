# fleet-mysql

MySQL for `kube/nuc01/fleet-config`. One replica on a 10Gi `longhorn`
volume; binary logging is off.

## Backups

`fleet-mysql-backup` dumps the `fleet` database at 02:30 UTC to
`s3://backups/fleet-mysql/` on backup-rustfs and keeps 30 days.

Restore into a running instance:

```sh
mc cat rustfs/backups/fleet-mysql/<file>.sql.gz | gunzip \
  | kubectl -n fleet exec -i fleet-mysql-0 -- sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot'
```

Scale the `fleet` Deployment to 0 first so the server isn't writing during
the restore.

## Secrets

- `fleet-mysql-credentials`: `root-password`, `mysql-password` (the `fleet`
  user; also read by the chart). The init only applies these on an empty
  volume, so rotating them later means changing them in MySQL as well.
- `backup-rustfs-credentials`: same keys as the other backup-rustfs clients.

Edit with `sops kube/nuc01/fleet-mysql/<file>.enc.yaml`.
