#!/bin/bash

### download metars
curl "https://aviationweather.gov/adds/dataserver_current/current/metars.cache.csv" | sed '1,5d' > metars.csv

### use vrt to convert to points
ogr2ogr -overwrite -s_srs 'EPSG:4326' -t_srs 'EPSG:3857' metars_point.gpkg metars.vrt
