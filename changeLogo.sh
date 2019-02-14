#!/bin/bash

# retrieve arguments using format argument=value
for i in "$@"
do
case $i in
    -r=*|--read-mode=*)
    READ_MODE="${i#*=}"
    shift
    ;;
    -i=*|--import-images=*)
    IMPORT_IMAGES="${i#*=}"
    shift
    ;;
    -u=*|--user=*)
    DBUSER="${i#*=}"
    shift
    ;;
    -p=*|--password=*)
    DBPASSWORD="${i#*=}"
    shift
    ;;
    *)
    # unknown option
    ;;
esac
done

if [[ -z "$DBUSER" ]]; then
	echo "[ERROR] You must provide a DB user";
    exit;
fi
if [[ -z "$DBPASSWORD" ]]; then
	echo "[ERROR] You must provide a DB password";
    exit;
fi
if [[ -z "$READ_MODE" ]]; then
  READ_MODE="db";
fi
if [[ -z "$IMPORT_IMAGES" ]]; then
  IMPORT_IMAGES="yes";
fi

# Retrieve configuration settings
echo "Reading properties..."
PROPS='config/script.properties';
sourceHost=$(awk -F = '/^db.source.host/ {print $2}' $PROPS);
sourcePort=$(awk -F = '/^db.source.port/ {print $2}' $PROPS);
sourceSid=$(awk -F = '/^db.source.sid/ {print $2}' $PROPS);

destHost=$(awk -F = '/^db.destination.host/ {print $2}' $PROPS);
destPort=$(awk -F = '/^db.destination.port/ {print $2}' $PROPS);
destSid=$(awk -F = '/^db.destination.sid/ {print $2}' $PROPS);

text=$(awk -F = '/^image.text/ {print $2}' $PROPS);
font=$(awk -F = '/^image.font.type/ {print $2}' $PROPS);
fontSize=$(awk -F = '/^image.font.size/ {print $2}' $PROPS);
color=$(awk -F = '/^image.font.color/ {print $2}' $PROPS);
borderColor=$(awk -F = '/^image.font.bordercolor/ {print $2}' $PROPS);

client=$(awk -F = '/^openbravo.client/ {print $2}' $PROPS);
retail=$(awk -F = '/^openbravo.retail/ {print $2}' $PROPS);

importScriptFile=$(awk -F = '/^import.script.file/ {print $2}' $PROPS);

if [[ $IMPORT_IMAGES == "script" ]]; then
  rm -f $importScriptFile;
fi

if [[ $READ_MODE == "imagefile" ]]; then
  echo "Skipping image generation. Taking images from /tmp/images/"$client"...";
elif [[ $READ_MODE == "readonly" ]]; then
  echo "Skipping generation and importation of images. Generating data files in /tmp...";
else
  mkdir -p "/tmp/images/"$client;
  rm -f "/tmp/images/"$client/*;
fi

declare -a images=("your_company_menu_image" "your_company_document_image" "your_company_big_image" "si_your_company_login_image"
                   "si_your_company_menu_image" "si_your_company_big_image" "si_your_company_document_image");

if [[ $retail == "yes" ]]; then
  images+=("em_obpos_company_login_image");
fi

for i in "${images[@]}" 
do
  if [[ $READ_MODE == "db" || $READ_MODE == "readonly" || $READ_MODE == "datafile" ]]; then

    if [[ $READ_MODE == "datafile" ]]; then
      echo "Retrieving image from data file...";
    else
      # Getting the image from source database
      export PGPASSWORD=$DBPASSWORD;
      echo "Exporting image "$i"...";
      psql -h $sourceHost -p $sourcePort -U $DBUSER -d $sourceSid -q -f exportImage.sql -v v1="'"$i"'" -v v2="'"$client"'" ;
    fi

    imageData="/tmp/"$i".data";
    read imageWidth imageHeight imageType <<< $(awk -F"|" '{print $1" "$2" "$3}' $imageData);
    if [[ $imageType == *"/"* ]]; then
      read imageType <<< $(echo ${imageType} | awk -F"/" '{print $2}');
      if [[ $imageType == "svg+xml" ]]; then
        imageType="svg";
      fi
    fi

    if [[ $READ_MODE == "readonly" ]]; then
      continue;
    fi
  
    image="/tmp/image."$imageType;
    imageInfo="/tmp/"$i".hex";
    xxd -p -r $imageInfo > $image;
    if [[ $imageType == "svg" ]]; then
      # to avoid problems with svg format when adding the watermark
      convert $image /tmp/image.png;
      image="/tmp/image.png";
      imageType="png";
    fi

    # Editing the image
    echo "Adding watermark..."
    imageFinal="/tmp/images/"$client"/"$i"."$imageType;
    convert -pointsize ${fontSize} -font ${font} -gravity center -draw "fill ${borderColor} text 0,0 ${text} fill ${color} text 1,1 ${text}" $image $imageFinal;

    echo $(identify -format "%[fx:w]|%[fx:h]" $imageFinal | awk -F"|" '{print $1" "$2}') > "/tmp/images/"$client"/"$i".size";
  elif [[ $READ_MODE == "imagefile" ]]; then
    image="";
    sizeFile="";
    imageType="";
    imageFiles="/tmp/images/"$client"/*";
    for filename in $imageFiles; do
      shortname=${filename##*/}
      name=$(echo "$shortname" | cut -f 1 -d '.');
      if [[ $name == $i ]]; then
      	image=$filename;
        imageType=$(echo "$shortname" | cut -f 2 -d '.');
        sizeFile=$(echo "$filename" | cut -f 1 -d '.')".size";
        break;
      fi
    done
    if [[ $image == "" ]]; then
      echo "[WARN] Image "$i" not found.";
      continue;
    fi
    if [[ ! -f $sizeFile ]]; then
      read imageWidth imageHeight <<< $(identify -format "%[fx:w]|%[fx:h]" $image | awk -F"|" '{print $1" "$2}');
    else
      read imageWidth imageHeight <<< $(cat $sizeFile);
    fi
    imageFinal="/tmp/images/"$client"/"$i"."$imageType;
  else
    echo "Unsupported read mode "$READ_MODE;
    exit;
  fi
  echo "Image data: size = "$imageWidth"x"$imageHeight" format = "$imageType;

  if [[ $IMPORT_IMAGES == "script" ]]; then
    # Generating script for importing images
    export PGPASSWORD=$DBPASSWORD;
    psql -h $sourceHost -p $sourcePort -U $DBUSER -d $sourceSid -q -f createImportImagesScript.sql -v v1="'"$imageFinal"'" -v v2=$imageWidth -v v3=$imageHeight -v v4=$imageType -v v5="'"$i"'" -v v6="'"$client"'" >> $importScriptFile 2>&1;
  elif [[ $IMPORT_IMAGES == "yes" ]]; then
    # Importing the image into destination database
    export PGPASSWORD=$DBPASSWORD;
    echo "Importing image...";
    psql -h $destHost -p $destPort -U $DBUSER -d $destSid -q -f importImage.sql -v v1="'"$imageFinal"'" -v v2=$imageWidth -v v3=$imageHeight -v v4=$imageType -v v5="'"$i"'" -v v6="'"$client"'";
    echo "Image "$i" imported successfully";
  else
    echo "Skipping importing of image "$i;
  fi
done
if [[ $IMPORT_IMAGES == "script" ]]; then
  sed -e s/psql:createImportImagesScript.sql:46:[[:blank:]]NOTICE:[[:blank:]][[:blank:]]//g -i $importScriptFile;
  echo "Script for image importing created: "$importScriptFile"";
fi
