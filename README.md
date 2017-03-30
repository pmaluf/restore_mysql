# restore_mysql

Script to automate the process of restoring MySQL databases using Netapp FlexClone

## Notice

This script was tested in:

* Linux
  * OS Distribution: Red Hat Enterprise Linux Server release 6.5 (Santiago)
  * MySQL Database: 5.5, 5.6 and 5.7
  * GNU bash: 4.1.2
  * Docker: 1.12.6

* To backup see: [snapmanager.sh](https://github.com/pmaluf/snapmanager)

## Prerequisities

* Docker installed
* MySQL Client installed
* Create an user on NetApp Server with vol_snapshot and cli_exportfs privileges and setup the SSH passwordless authentication.
* Works only with backups made using Netapp Snapshot feature. 

Change it the SSHUSER variable on mysql_restore.sh
```
SSHUSER="<NETAPP_SSHPASSWORDLESS_USER>"
```

* Grant SELECT to user:
```
mysql> GRANT SELECT ON *.* TO 'backupmanager'@'%' IDENTIFIED BY "<MYPASSWORD>";
mysql> flush privileges;
```


## How to use it

```
# restore_mysql.sh - MySQL restore using NETAPP FlexClone
# Created: Paulo Victor Maluf - 03/2017
#
# Parameters:
#
#   restore_mysql.sh --help
#
#    Parameter           Short Description                                                              Default
#    ------------------- ----- ------------------------------------------------------------------------ -----------------
#    --username             -u [OPTIONAL] MySQL username                                                backup
#    --password             -p [OPTIONAL] MySQL password                                                *******
#    --snap-name            -n [OPTIONAL] Snapshot name (See the --list option)
#    --cleanup              -c [OPTIONAL] Destroy volume clone and shutdown and remove docker image
#    --config-dir           -d [OPTIONAL] Config directory                                              ./cnf/common
#    --volume-name          -v [REQUIRED] Volume name (Ex: nfs_tester_db_2)
#    --mysql-version        -m [REQUIRED] MySQL version to be restored (Ex: 5.5, 5.6, 5.7)
#    --list                 -l [OPTIONAL] List snapshots
#    --restore-only         -r [OPTIONAL] Only take a restore of database without shutdown and destroy
#    --netapp-server        -s [REQUIRED] Netapp server
#    --help                 -h [OPTIONAL] help
#
#   Ex.: restore_mysql.sh [OPTIONS] --volume-name <NFS_VOLUMN> --netapp-server <SERVER> --mysql-version <MYSQL_VERSION>
```

* List all snapshots
```
bash restore_mysql.sh --volume-name nfs_teste_linux --netapp-server netapp-db-1.nas.infra --list
Checking netapp ssh connectivity...[ OK ]
Checking netapp volume...[ OK ]
Listing snapshots... 
Volume nfs_teste_linux
working...

  %/used       %/total  date          name
----------  ----------  ------------  --------
  1% ( 1%)    0% ( 0%)  Mar 30 11:01  nfs_teste_linux_1_data-300317105043 
  2% ( 0%)    1% ( 0%)  Mar 30 10:19  nfs_teste_linux_1_data-300317100806 
  3% ( 1%)    1% ( 0%)  Mar 30 00:11  nfs_teste_linux_1_data-300317000002 
  5% ( 3%)    2% ( 1%)  Mar 29 00:11  nfs_teste_linux_1_data-290317000002 
  8% ( 3%)    3% ( 1%)  Mar 28 00:11  nfs_teste_linux_1_data-280317000002 
 10% ( 3%)    4% ( 1%)  Mar 27 00:11  nfs_teste_linux_1_data-270317000002 
 12% ( 2%)    5% ( 1%)  Mar 26 00:11  nfs_teste_linux_1_data-260317000002 
 14% ( 2%)    5% ( 1%)  Mar 25 00:10  nfs_teste_linux_1_data-250317000002 
 16% ( 3%)    6% ( 1%)  Mar 24 00:11  nfs_teste_linux_1_data-240317000002 
 18% ( 2%)    7% ( 1%)  Mar 23 00:10  nfs_teste_linux_1_data-230317000002 
 19% ( 3%)    8% ( 1%)  Mar 22 00:10  nfs_teste_linux_1_data-220317000002 
 21% ( 3%)    9% ( 1%)  Mar 21 00:10  nfs_teste_linux_1_data-210317000002 
 23% ( 3%)   10% ( 1%)  Mar 20 00:08  nfs_teste_linux_1_data-200317000001 
 24% ( 3%)   11% ( 1%)  Mar 19 00:08  nfs_teste_linux_1_data-190317000001 
 26% ( 3%)   12% ( 1%)  Mar 18 00:08  nfs_teste_linux_1_data-180317000001 
 27% ( 3%)   13% ( 1%)  Mar 17 00:08  nfs_teste_linux_1_data-170317000001 
 29% ( 3%)   14% ( 1%)  Mar 16 00:08  nfs_teste_linux_1_data-160317000001 
 31% ( 4%)   15% ( 1%)  Mar 15 00:08  nfs_teste_linux_1_data-150317000001 
 34% ( 6%)   17% ( 2%)  Mar 14 00:08  nfs_teste_linux_1_data-140317000001 
 36% ( 6%)   19% ( 2%)  Mar 13 00:08  nfs_teste_linux_1_data-130317000001 
 39% ( 5%)   21% ( 2%)  Mar 12 00:08  nfs_teste_linux_1_data-120317000002 
 41% ( 6%)   23% ( 2%)  Mar 11 00:08  nfs_teste_linux_1_data-110317000001 
 43% ( 6%)   25% ( 2%)  Mar 10 00:08  nfs_teste_linux_1_data-100317000001 
 45% ( 6%)   28% ( 2%)  Mar 09 00:08  nfs_teste_linux_1_data-090317000001 
 47% ( 6%)   30% ( 2%)  Mar 08 00:08  nfs_teste_linux_1_data-080317000001 
 48% ( 6%)   32% ( 2%)  Mar 07 00:08  nfs_teste_linux_1_data-070317000001 
 50% ( 6%)   34% ( 2%)  Mar 06 00:08  nfs_teste_linux_1_data-060317000001 
 50% ( 0%)   34% ( 0%)  Mar 05 00:08  nfs_teste_linux_1_data-050317000001 
 50% ( 0%)   34% ( 0%)  Mar 04 00:08  nfs_teste_linux_1_data-040317000001 
 50% ( 0%)   34% ( 0%)  Mar 03 00:08  nfs_teste_linux_1_data-030317000002 

```

* Make a restore from the lastest snapshot avaiable
```
./restore_mysql.sh --netapp-server nas-virtual-1.nas.infra --volume-name nfs_teste_linux_1_data --mysql-version 5.5
Checking netapp ssh connectivity...[ OK ]
Checking netapp volume...[ OK ]
Checking snapshots...[ OK ]
Using snapshot: nfs_teste_linux_1_data-300317105043
Checking if the clone already exists....[ OK ]
Creating clone volume from snapshot...[ OK ]
Exporting the volume...[ OK ]
Disable .snapshot directories...[ OK ]
Mounting nfs /storage/nfs_teste_linux_1_data/data...[ OK ]
Changing nfs ownership...[ OK ]
Running MySQL 5.5 docker image, this will take about 60 seconds...[ OK ]
Getting container ip...[ OK ]
Checking MySQL connection on 172.17.0.2:3306...[ OK ]
Running mysql tests...
+----------+----------------------+
| count(1) | table_schema         |
+----------+----------------------+
|        1 | database1            |
|        2 | database2            |
|       40 | information_schema   |
|       25 | mysql                |
|       17 | performance_schema   |
+----------+----------------------+
Shutdown docker...[ OK ]
Umounting nfs /storage/nfs_teste_linux_1_data/data...[ OK ]
Taking volune clone_nfs_teste_linux_1_data_tmp offline...[ OK ]
Destroy volune clone_nfs_teste_linux_1_data_tmp...[ OK ]
Restore completed
```

* Make a restore from snapshot
```
./restore_mysql.sh --netapp-server nas-virtual-1.nas.infra --volume-name nfs_teste_linux_1_data --mysql-version 5.5 --snap-name nfs_teste_linux_1_data-300317105043
Checking netapp ssh connectivity...[ OK ]
Checking netapp volume...[ OK ]
Checking snapshots...[ OK ]
Using snapshot: nfs_teste_linux_1_data-300317105043
Checking if the clone already exists....[ OK ]
Creating clone volume from snapshot...[ OK ]
Exporting the volume...[ OK ]
Disable .snapshot directories...[ OK ]
Mounting nfs /storage/nfs_teste_linux_1_data/data...[ OK ]
Changing nfs ownership...[ OK ]
Running MySQL 5.5 docker image, this will take about 60 seconds...[ OK ]
Getting container ip...[ OK ]
Checking MySQL connection on 172.17.0.2:3306...[ OK ]
Running mysql tests...
+----------+----------------------+
| count(1) | table_schema         |
+----------+----------------------+
|        1 | database1            |
|        2 | database2            |
|       40 | information_schema   |
|       25 | mysql                |
|       17 | performance_schema   |
+----------+----------------------+
Shutdown docker...[ OK ]
Umounting nfs /storage/nfs_teste_linux_1_data/data...[ OK ]
Taking volune clone_nfs_teste_linux_1_data_tmp offline...[ OK ]
Destroy volune clone_nfs_teste_linux_1_data_tmp...[ OK ]
Restore completed
```

## License

This project is licensed under the MIT License - see the [License.md](License.md) file for details
