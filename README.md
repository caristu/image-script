# image-script
Utility script for migrating and watermarking images between Openbravo environments using Ubuntu

## Prerequisites
The script requires the installation of the following software:
- PostgreSQL (https://www.postgresql.org/)
- ImageMagick (https://help.ubuntu.com/community/ImageMagick)

## Running the script
The script is configured through the following properties file:
```
config/script.properties
```
Here we can configure:
- The DB connection settings for both the source and destination databases.
- Openbravo information, like the ID of the client whose images will be exported.
- Image properties that allow to customize the exported images.

Having the properties file configured, the script can be run by executing:
```
./changeLogo --user=<db_user> --password=<db_password>
```
This will perform the following steps:<br/>
1- Retrieve the images<br/>
2- Edit the images and watermark them, placing the resulting images in the /tmp/images folder<br/>
3- Import the edited images into the destination database<br/>

Step 1) can be executed in different ways depending on the value provided by the --read-mode parameter:

- <b>db</b>: retrieve the images from the source database.
- imagefile: retrieves the images from the local computer. This mode is useful once the script has been run once with the db mode, to avoid executing the edition part.
- readonly: it just reads the images from the source database and generates the data files. The edition and import processes are skipped.
- datafile: it generates the images from data files. To execute this mode, previously the data files should be generated using the readonly mode.

```
./changeLogo --user=<db_user> --password=<db_password> --skip-image-generation=yes
```
or what it is the same:
```
./changeLogo -u=<db_user> -p=<db_password> -s=yes
```
It is also possible to skip the importing step and instead generate a .sql script with the statements for importing the images:
```
./changeLogo --user=<db_user> --password=<db_password> --import-images=no
```
or equivalently:
```
./changeLogo --user=<db_user> --password=<db_password> -i=no

Note that the location of the script file should be specified in the properties file.

