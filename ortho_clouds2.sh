#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
place='Seoul'
data=($(psql -d world -c "\COPY (SELECT fid, round(ST_X(ST_Centroid(geom))), round(ST_Y(ST_Centroid(geom))) FROM ne_10m_populated_places WHERE nameascii = '${place}') TO STDOUT"))
extent=($(( ${data[1]} - 40 )) $(( ${data[2]} - 20 )) $(( ${data[1]} + 40 )) $(( ${data[2]} + 20 )))
#lon_0=60
#lat_0=0
lon_0=${data[1]}
lat_0=${data[2]}
height=512
width=512
height_frame=512
width_frame=1024
#height_frame=1920
#width_frame=1080
resize=50

rm -f $PWD/../tmp/*

### layers
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=ortho +lat_0='${lat_0}' +lon_0='${lon_0}' +ellps='sphere'' -r cubicspline -ts ${height} ${height} $PWD/../maps/naturalearth/raster/HYP_HR_SR_OB_DR_5400_2700.tif $PWD/../tmp/layer0_${lon_0}_${lat_0}.tif

counter=1
ls $PWD/../data/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -t_srs '+proj=ortho +lat_0='${lat_0}' +lon_0='${lon_0}' +ellps='sphere'' -r cubicspline -ts ${height} ${height} /vsistdin/ $PWD/../tmp/layer1_${lon_0}_${lat_0}_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### composite
count=$(ls $PWD/../tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width_frame}x${height_frame} xc:none \( $PWD/../tmp/layer0_${lon_0}_${lat_0}.tif -resize ${resize}% -level 50%,100% \) -gravity center -compose over -composite \( $PWD/../tmp/layer1_${lon_0}_${lat_0}_$(printf "%06d" ${counter}).tif -resize ${resize}% -level 50%,100% \) -gravity center -compose over -composite $PWD/../tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
video=$(echo ${PWD}/../out/ortho_${lon_0}_${lat_0}_$(date +%m_%d_%H%M%S).mp4)
ls -tr $PWD/../tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i $PWD/../tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart ${video}
ffplay -loop 0 ${video}
