#!/bin/bash

for i in "$@"
do
case $i in
    -s=*|--skip-image-generation=*)
    SKIP_GENERATION="${i#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

if [[ $SKIP_GENERATION == "yes" ]]; then
  echo "Skipping image generation. Taking images from /tmp/images..."
fi

# Retrieve configuration settings
echo "Reading properties..."
PROPS='config/script.properties';
sourceHost=$(awk -F = '/^db.source.host/ {print $2}' $PROPS);
sourcePort=$(awk -F = '/^db.source.port/ {print $2}' $PROPS);
sourceSid=$(awk -F = '/^db.source.sid/ {print $2}' $PROPS);
sourceUser=$(awk -F = '/^db.source.user/ {print $2}' $PROPS);
sourcePassword=$(awk -F = '/^db.source.password/ {print $2}' $PROPS);

destHost=$(awk -F = '/^db.destination.host/ {print $2}' $PROPS);
destPort=$(awk -F = '/^db.destination.port/ {print $2}' $PROPS);
destSid=$(awk -F = '/^db.destination.sid/ {print $2}' $PROPS);
destUser=$(awk -F = '/^db.destination.user/ {print $2}' $PROPS);
destPassword=$(awk -F = '/^db.destination.password/ {print $2}' $PROPS);

imageDir=$(awk -F = '/^image.dir/ {print $2}' $PROPS);
text=$(awk -F = '/^image.text/ {print $2}' $PROPS);
font=$(awk -F = '/^image.font.type/ {print $2}' $PROPS);
fontSize=$(awk -F = '/^image.font.size/ {print $2}' $PROPS);
color=$(awk -F = '/^image.font.color/ {print $2}' $PROPS);
borderColor=$(awk -F = '/^image.font.bordercolor/ {print $2}' $PROPS);

client=$(awk -F = '/^openbravo.client/ {print $2}' $PROPS);

mkdir -p /tmp/images;

declare -a images=("your_company_menu_image" "your_company_document_image" "your_company_big_image" "em_obpos_company_login_image"
	               "si_your_company_login_image" "si_your_company_menu_image" "si_your_company_big_image" "si_your_company_document_image");

for i in "${images[@]}" 
do 
  # Getting the image from source database
  if [[ $SKIP_GENERATION != "yes" ]]; then
    export PGPASSWORD=$sourcePassword;
    echo "Exporting image "$i"..."
    psql -h $sourceHost -p $sourcePort -U $sourceUser -d $sourceSid -q -f exportImage.sql -v v1="'"$i"'" -v v2="'"$client"'" ;
    read imageWidth imageHeight imageType <<< $(awk -F"|" '{print $1" "$2" "$3}' '/tmp/image.data');
    if [[ $imageType == *"/"* ]]; then
	  read imageType <<< $(echo ${imageType} | awk -F"/" '{print $2}');
	  if [[ $imageType == "svg+xml" ]]; then
		imageType="svg";
	  fi
    fi
    image="/tmp/image."$imageType;
    xxd -p -r /tmp/image.hex > $image;
    if [[ $imageType == "svg" ]]; then
      # to avoid problems with svg format when adding the watermark
	  convert $image /tmp/image.png;
	  image="/tmp/image.png";
	  imageType="png";
	fi
  else
  	image="";
  	imageType="";
    for filename in /tmp/images/*; do
      name=${filename##*/}
      name=$(echo "$name" | cut -f 1 -d '.');
      if [[ $name == $i ]]; then
      	image=$filename;
        imageType=$(echo "$name" | cut -f 2 -d '.');
        break;
      fi
    done
    if [[ $image == "" ]]; then
      echo "[WARN] Image "$i" not found.";
      continue;
    fi
    read imageWidth imageHeight <<< $(identify -format "%[fx:w]|%[fx:h]" $image | awk -F"|" '{print $1" "$2}');
  fi
  echo "Image data: size = "$imageWidth"x"$imageHeight" format = $imageType";

  # Editing the image
  echo "Adding watermark..."
  imageFinal="/tmp/images/"$i"."$imageType;
  convert -pointsize ${fontSize} -font ${font} -gravity center -draw "fill ${borderColor} text 0,0 ${text} fill ${color} text 1,1 ${text}" $image $imageFinal;

  # Importing the image into destination database
  export PGPASSWORD=$destPassword;
  echo "Importing image..."
  psql -h $destHost -p $destPort -U $destUser -d $destSid -q -f importImage.sql -v v1="'"$imageFinal"'" -v v2=$imageWidth -v v3=$imageHeight -v v4=$imageType -v v5="'"$i"'" -v v6="'"$client"'" ;
  echo "Image "$i" imported successfully"
done