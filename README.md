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
./changeLogo
```
This will perform the following steps:
1- Retrieve the images from the source database
2- Edit the images and watermark them, placing the resulting images in the /tmp/images folder
3- Import the edited images into the destination database

Once the script has been run once, the image edition step can be skipped using the --skip-image-generation parameter:
```
./changeLogo --skip-image-generation=yes
```
or what it is the same:
```
./changeLogo -s=yes
```

