# Production de SDMs avec maxent sur les donnees du junco ardoisé - Junco hyemalis
# origine des donnees d'occurences - donnees utilisees par Vincent Bellavance dans le cadre de sa maitrise
# origine des donnees bioclimatiques - WorldClim - https://www.worldclim.org/data/bioclim.html
# package & methode utilises - ENMeval & maxent - vignette https://jamiemkass.github.io/ENMeval/articles/ENMeval-2.0-vignette.html

#### Packages ####
# ------------- #
source("packages_n_data.r")

#### Environmental data raster from Francois Rousseu ####
# ----------------------------------------------------- #
pred <- terra::rast("/home/claire/BDQC-GEOBON/data/Maxent/CROPPED_predictors.tif")
names(pred)
x11()
plot(pred[[11]])

## --> keep tmean [1], prec [2], xxx_esa [39:51], elevation [20], truggedness [19]
# pred2 <- subset(pred, c(1, 2, 19, 20, 39:51))
# names(pred2)
# pred2

#### species data ####
# ------------------ #

## --> data from Vincent Bellavance ms
obs_sf <- st_read("/home/claire/BDQC-GEOBON/data/Bellavance_data/sf_converted_occ_pres_only2/junco_hyemalis.gpkg") # obs already during the breeding season

dim(obs_sf)
class(obs_sf)
head(obs_sf)
names(obs_sf)

# crs homogenization to raster CRS
obs_sf2 <- st_transform(obs_sf,
    # crs = st_crs(pred2)
    crs = st_crs(pred)
)
head(obs_sf2)

# keep only the converted coordinates and deletion of duplicated ones
coord <- as.data.frame(st_coordinates(obs_sf2))
occs <- coord[!duplicated(coord), ]
dim(occs)
dim(coord)

x11()
plot(pred[[1]])
points(occs, pch = 20, cex = .5)

names(occs) <- c("lon", "lat")

#### Study extent ####
# ------------------ #
region <- st_read("/home/claire/BDQC-GEOBON/GITHUB/BDQC_SDM_benchmark_initial/local_data/REGION_interet_sdm.gpkg")
x11()
plot(st_geometry(region))

## --> Use extent of occs
# range <- st_bbox(obs_sf2)

## --> Use extent of QC
# can <- readRDS("/home/claire/BDQC-GEOBON/data/gadm/gadm41_CAN_1_pk.rds")
# qc <- can[11, ]
# plot(qc)

# Conversion from sp to sf ####
# qc_sf <- st_as_sf(qc)
# crs homogenization to raster CRS
# qc_utm <- st_transform(qc_sf,
#     crs = st_crs(pred2)
# )
region <- st_transform(region,
    crs = st_crs(pred)
)

x11()
plot(pred[[1]])
plot(st_geometry(qc_utm), add = T)
range <- st_bbox(qc_utm)

## --> Get the range
# exten <- ext(
#     range[1],
#     range[3],
#     range[2],
#     range[4]
# )
# Crop environmental rasters to match the study extent
# envs_bg <- crop(pred2, occs_buf)
# envs_bg <- crop(pred2, exten)

# Tests
# Temperatures
# plot(envs_bg[[1]], main = names(pred2)[1])
# points(occs)

# Precipitations
# plot(envs_bg[[2]], main = names(pred2)[2])
# points(occs)

#### ---> Création des rasters pour la composantes autocorrélation spatiale ####
# ---------------------------------------------------------------------------- #
spatial <- pred[[1]]

# x des centroides pour chaque pixel
x <- init(spatial, "x")
names(x) <- "x"

# y des centroides pour chaque pixel
y <- init(spatial, "y")
names(y) <- "y"

# interaction entre x & y
xy <- x * y
names(xy) <- "xy"

spatial <- c(x, y, xy)

spatial_crop <- terra::crop(spatial, vect(region))
spatial <- terra::mask(spatial_crop, vect(region))
plot(spatial_mask[[1]])

#### ----> pseudo-absence without bias ####
pseudo_abs_noBias <- st_read("/home/claire/BDQC-GEOBON/GITHUB/BDQC_SDM_benchmark_initial/local_data/TdB_bench_maps/pseudo_abs/CROPPED_pseudo-abs_region_Maxent_noBias.gpkg")
st_crs(pseudo_abs_noBias) == st_crs(region)
pseudo_abs_noBias <- st_transform(pseudo_abs_noBias, crs = st_crs(region))

x11()
plot(pred[[1]])
plot(st_geometry(region), add = T)
plot(st_geometry(pseudo_abs_noBias), add = T, pch = 20, cex = .5, col = "grey")

# From raster to polys
# polys <- as.polygons(envs_bg[[1]])
# bg_pts <- st_sample(st_as_sf(test_poly), 10000)

# plot(polys)
# plot(st_geometry(bg_pts), col = "red", add = T)


# bg <- raptr::randomPoints(
#     envs_bg[[1]],
#     n = 10000
# ) %>% as.data.frame()
# bg <- as.data.frame(st_coordinates(bg_pts))
# head(bg)
# colnames(bg) <- colnames(occs)

#### ----> pseudo-absence WITH bias ####
# sampling in all occurrences in db

pseudo_abs_bias <- st_read("/home/claire/BDQC-GEOBON/GITHUB/BDQC_SDM_benchmark_initial/local_data/TdB_bench_maps/pseudo_abs/CROPPED_pseudo-abs_junco_hyemalis_Maxent_Predictors_Bias_NoSpatial.gpkg")

st_crs(pseudo_abs_bias) == st_crs(region)
pseudo_abs_bias <- st_transform(pseudo_abs_bias, crs = st_crs(region))

x11()
plot(pred[[1]])
plot(st_geometry(region), add = T)
plot(st_geometry(pseudo_abs_bias), pch = 20, cex = .5, add = T)

# bg0 <- st_read("/home/claire/BDQC-GEOBON/data/Bellavance_data/total_occ_pres_only_versionR.gpkg",
#     query = "SELECT geom FROM total_occ_pres_only_versionR ORDER BY random() LIMIT 10"
# )

# bg00 <- as.data.frame(st_coordinates(bg0))
pseudo_abs_bias <- as.data.frame(st_coordinates(pseudo_abs_bias))

pseudo_abs_bias <- pseudo_abs_bias[!duplicated(pseudo_abs_bias), ]

# sample_n(bg, 10)
colnames(pseudo_abs_bias) <- colnames(occs)

# Visualization
plot(pred[[1]], main = names(pred)[1])
points(occs)
# plot(occs_buf, border = "blue", lwd = 3, add = TRUE)
points(pseudo_abs_bias, col = "red")

#### Partitioning occurences for eval ####
# -------------------------------------- #
# allowing cross-validation
# choice of the partitioning method
# can be done manually with the partitioning function or automatically in ENMeval()

# for illustration, test of the block method
block <- get.block(occs, pseudo_abs_bias, orientation = "lat_lon")
# Let's make sure that we have an even number of occurrences in each partition.
table(block$occs.grp)
table(block$bg.grp)
# We can plot our partitions on one of our predictor variable rasters to visualize where they fall in space.
# The ENMeval 2.0 plotting functions use ggplot2 (Wickham 2016)
x11()
par(mfrow = c(1, 2))

evalplot.grps(pts = occs, pts.grp = block$occs.grp, envs = raster(pred[[1]])) +
    ggplot2::ggtitle("Spatial block partitions: occurrences")

# PLotting the background shows that the background extent is partitioned in a way that maximizes evenness of points across the four bins, not to maximize evenness of area.

evalplot.grps(pts = pseudo_abs_bias, pts.grp = block$bg.grp, envs = raster(pred[[1]])) +
    ggplot2::ggtitle("Spatial block partitions: background")

#### Running ENMeval ####
# --------------------- #

maxL <- ENMevaluate(
    occs = occs,
    # envs = pred,
    bg = pseudo_abs_bias,
    # algorithm = "maxnet",
    algorithm = "maxent.jar",
    partitions = "block",
    tune.args = list(fc = "L", rm = 1:2)
)
maxL
class(maxL)
# saveRDS(
#     maxL,
#     "/home/claire/BDQC-GEOBON/SDM_Maxent_results/junco_hyemalis/junco_hyemalis_L_1-2_QC-buffer_Maxent-jar.rds"
# )
x11()
plot(maxL@predictions)

maxLQ <- ENMevaluate(
    occs = occs,
    envs = envs_bg,
    bg = bg,
    # algorithm = "maxnet",
    algorithm = "maxent.jar",
    partitions = "block",
    tune.args = list(fc = "LQ", rm = 1:2)
)
maxLQ

# saveRDS(
#     maxLQ,
#     "/home/claire/BDQC-GEOBON/SDM_Maxent_results/junco_hyemalis/junco_hyemalis_LQ_1-2_QC-buffer_Maxent-jar.rds"
# )

x11()
plot(maxLQ@predictions)
# plot(maxLQ@predictions[[1]])
# plot(maxLQ@predictions[[2]])

maxLQH <- ENMevaluate(
    occs = occs,
    envs = envs_bg,
    bg = bg,
    # algorithm = "maxnet",
    algorithm = "maxent.jar",
    partitions = "block",
    tune.args = list(fc = "LQH", rm = 1)
)
maxLQH

# saveRDS(
#     maxLQ,
#     "/home/claire/BDQC-GEOBON/SDM_Maxent_results/junco_hyemalis/junco_hyemalis_LQ_1-2_QC-buffer_Maxent-jar.rds"
# )

x11()
plot(maxLQH@predictions)

# Model Maxent - noPredictor - bias - spatial
maxLQH <- ENMevaluate(
    occs = occs,
    envs = spatial,
    bg = pseudo_abs_bias,
    # algorithm = "maxnet",
    algorithm = "maxent.jar",
    partitions = "block",
    tune.args = list(fc = "LQH", rm = 1)
)
maxLQH
x11()
plot(maxLQH@predictions)
plot(st_geometry(region), add = T)
