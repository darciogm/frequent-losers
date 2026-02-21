cd /home/darciogm1/projetos/bitter-pills/data/geocoding/shapefiles/Unidades_federacao

*Importing Shapefile
shp2dta using <file>.shp, database(db_<type of map>) coordinates(co_<type of map>) genid(<type of map>_id)

*Generating Maps
spmap <NUMERIC_VARIABLE> using co_<type of map>.dta, id(<type of map>_id)

