#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### video options
height=0
width=1920
height_frame=3820
width_frame=1920

rm -f $PWD/../tmp/*

### layers
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -r cubicspline -ts ${width} 0 -t_srs 'ESRI:53028' $PWD/../maps/naturalearth/raster/HYP_HR_SR_OB_DR.tif $PWD/../tmp/layer0.tif

counter=1
ls $PWD/../data/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -r cubicspline -ts ${width} 0 -t_srs 'ESRI:53028' /vsistdin/ $PWD/../tmp/layer1_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### composite
count=$(ls $PWD/../tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width_frame}x${height_frame} xc:none \( $PWD/../tmp/layer0.tif -level 50%,100% \) -gravity center -compose over -composite \( $PWD/../tmp/layer1_$(printf "%06d" ${counter}).tif -level 50%,100% \) -gravity center -compose over -composite $PWD/../tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
video=$(echo ${PWD}/../out/weather/weather_$(date +%m_%d_%H%M%S).mp4)
ls -tr $PWD/../tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i $PWD/../tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart ${video}
ffplay -loop 0 ${video}
