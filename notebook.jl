### A Pluto.jl notebook ###
# v0.20.19

using Markdown
using InteractiveUtils

# ╔═╡ 11f0bb79-7ca1-4b95-becb-e86018853763
# 1. Install necessary packages
begin 
    using Pkg;
    Pkg.add(["GeoStats", "GeoIO", "Tyler", "GeometryBasics", "Downloads", "WGLMakie", "CSV", "DataFrames"]);
    
    # --- Core Geospatial Framework ---
    # The main package of the GeoStats.jl ecosystem, providing the core types and methods for geostatistical problems.
    using GeoStats
    
    # --- Input/Output Modules ---
    # Provides functions to load and save a variety of geospatial file formats (e.g., Shapefile, GeoPackage, GeoTIFF).
    using GeoIO
	# Standard library for downloading files from URLs (e.g., via HTTP/HTTPS).
    using Downloads
    
    # --- Visualization & Geometry Modules ---
    # Imports the WGLMakie backend for creating interactive, web-based plots (e.g., in Pluto or Jupyter). It's aliased as `Mke`.
    import WGLMakie as Mke
    # Provides tools to fetch and display map tiles from providers like OpenStreetMap as a plot background.
    using Tyler
	using Tyler.TileProviders
	using Tyler.MapTiles
	
    # Provides fundamental geometric types (e.g., Point, Rect) used by the Makie plotting ecosystem.
    using GeometryBasics: Rect2f
    
    # --- Tabular Data Handling ---
    # A fast and flexible package for reading and writing comma-separated value (CSV) files.
    using CSV
    # Provides the `DataFrame` type, a powerful and feature-rich tool for working with tabular data in memory, similar to R's data.frame or pandas' DataFrame.
    using DataFrames
end


# ╔═╡ 47a5b8b4-11c8-460f-a91e-a6e05f912ea6
using Logging

# ╔═╡ 791e27f0-a9f0-11f0-91ec-7b09a9a9c617
md"""

# Drone Image Analysis with GeoStats.jl

This notebook presents a complete workflow for analyzing drone imagery in agricultural experiments, demonstrating how to leverage the **GeoStats.jl** ecosystem in Julia. Inspired by the functionalities of **FIELDimageR** (R), we start from an **orthomosaic** (generated via *OpenDroneMap™*) and use the GeoStats.jl tools to:

* load and organize geospatial data;
* calculate **vegetation indices**;
* delineate **plots** and extract metrics per plot;
* **summarize** and visualize the results.

The goal is to showcase how GeoStats.jl provides an **integrated, high-performance framework** for geospatial data science, allowing not only the replication of traditional agronomic analyses but also the ability to **extend** them with advanced **geostatistics** techniques.
"""

# ╔═╡ 8115b77f-817c-495d-8f9f-4e325b424dae
begin
	# Define the direct RAW URLs for the files on GitHub
	url_tif = "https://raw.githubusercontent.com/marcosdanieldasilva/AgricultureTutorials/main/data/rgb_ex1.tif"
	url_csv = "https://raw.githubusercontent.com/marcosdanieldasilva/AgricultureTutorials/main/data/data_ex1.csv"
	
	# Define the local names for the files
	nome_tif = "rgb_ex1.tif"
	nome_csv = "data_ex1.csv"

	# Download and load the image into the `img` variable
	println("Downloading TIF image from GitHub...")
	Downloads.download(url_tif, nome_tif)
	# Load, Select and rename the first three bands to R, G, and B.
	img = GeoIO.load(nome_tif) |> Select(1=> "R", 2 => "G", 3 => "B")
	println("Image successfully loaded into the 'img' variable.")

	# Download and load the table into the `data` variable
	println("\nDownloading CSV table from GitHub...")
	Downloads.download(url_csv, nome_csv)
	data = CSV.read(nome_csv, DataFrame)
	println("Table successfully loaded into the 'data' variable.")

	# Show the first few rows of the table to confirm
	println("\nPreview of the 'data' table:")
	display(first(data, 5))
end

# ╔═╡ 23bb4bbe-0187-4ac5-bd23-82ea6c50c520
describe(img)

# ╔═╡ d09bebca-7acf-4cea-b873-067844cd84a9
"""
    ColorView(; color=RGB, low=0.02, high=0.98, cname="RGB")

Creates a reusable GeoStats.jl transform for color visualization.

This function is necessary because raw sensor data (e.g., from a drone or satellite)
often has a wide dynamic range (e.g., 12-bit or 16-bit integers) that cannot be displayed
directly on a screen. This transform replicates the common "contrast stretch"
seen in GIS software like QGIS.

It first performs a percentile stretch using `LowHigh` and then converts the
normalized R, G, B channels into a single color column.

# Parameters
- `color`: The function to use for creating a color object. Defaults to `RGB`.
- `low`: The lower percentile for the contrast stretch. Defaults to `0.02` (2nd percentile).
- `high`: The upper percentile for the contrast stretch. Defaults to `0.98` (98th percentile).
- `cname`: The name of the final output color column. Defaults to `"RGB"`.

Setting `low=0.0` and `high=1.0` will perform a full stretch between the absolute
minimum and maximum values of the data.
"""
ColorView(; color=RGB, low=0.02, high=0.98, cname="RGB") = 
    LowHigh(; low, high) → Map(color => cname)


# ╔═╡ f696ca04-42bd-4c79-a469-5644fd0574d2
# Create the default 2%-98% contrast stretch transform.
processed_image = img |> ColorView()

# ╔═╡ 4e7f15bf-74e3-40e5-a66a-1ed4b41cbc7f
processed_image |> viewer

# ╔═╡ 2b47670e-46d7-491f-89ab-924599eb136b
# Or you can create a transform for a full min-to-max stretch.
full_range_image = img |> ColorView(low=0.0, high=1.0)

# ╔═╡ b34b67e4-0dd8-453c-a1d6-cef1be0786aa
full_range_image |> viewer

# ╔═╡ 9519e9fc-2345-4deb-bb98-4852b588dc46
# Define `extented_box` to enlarge the extent of a Meshes.jl `Box`.
function extented_box(box::Box)

    # Get min and max corner coordinates.
    cmin, cmax = coords.(extrema(box))

    # Extract latitude/longitude (assumes geographic coords).
    lat1, lon1 = (cmin.lat, cmin.lon) .|> ustrip
    lat2, lon2 = (cmax.lat, cmax.lon) .|> ustrip

    # Compute width (lon) and height (lat).
    δlon = abs(lon1 - lon2)
    δlat = abs(lat1 - lat2)

    # Build a larger rectangular extent.
    extent = Rect2f(lon1 - δlon/2, lat1 - δlat/2, 2δlon, 2δlat)

    return extent
end

# ╔═╡ cea06d2a-d549-4d4d-a0fa-402a5def8536
begin
	# Get bounding box in Lat/Lon (syntax shown here is not valid).
	box = boundingbox(processed_image.geometry |> Proj(LatLon))
	
	# Expand the extent.
	extent = extented_box(box)
	
	# Choose Google Maps tile provider.
	provider = TileProviders.Google()
	
	Tyler.Map(extent; provider)

end

# ╔═╡ 28bbbdb6-2ce5-4bfd-bf00-d6add78c38b9
# Create map and overlay RGB geometry (reprojection syntax is not correct).
with_logger(SimpleLogger(stderr, Logging.Error)) do
    m = Tyler.Map(extent; provider);
    viz!(processed_image.geometry |> Proj(WebMercator), color = processed_image.RGB)
    return m
end

# ╔═╡ 5d73c7a8-d5e0-4da2-b9fb-39e924cb913e
# Function to convert numerical R, G, B values to the Hue color channel.
function to_hue(r, g, b)
    # Create an RGB color object from the numbers.
    rgb = RGB(r, g, b)
    # Convert the color from RGB to HSV (Hue, Saturation, Value).
    hsv = HSV(rgb)
    # Return only the Hue component.
    return hsv.h
end

# ╔═╡ fcad4298-c839-4f8c-9e9f-19dce1ce60a3
# Apply the `to_hue` function across the `rgb` GeoTable,
# creating a new column named "HUE" with the results.
img_hue = img |> Map(["R","G","B"] => to_hue => "HUE")

# ╔═╡ Cell order:
# ╟─791e27f0-a9f0-11f0-91ec-7b09a9a9c617
# ╠═11f0bb79-7ca1-4b95-becb-e86018853763
# ╠═8115b77f-817c-495d-8f9f-4e325b424dae
# ╠═23bb4bbe-0187-4ac5-bd23-82ea6c50c520
# ╠═d09bebca-7acf-4cea-b873-067844cd84a9
# ╠═f696ca04-42bd-4c79-a469-5644fd0574d2
# ╠═4e7f15bf-74e3-40e5-a66a-1ed4b41cbc7f
# ╠═2b47670e-46d7-491f-89ab-924599eb136b
# ╠═b34b67e4-0dd8-453c-a1d6-cef1be0786aa
# ╠═9519e9fc-2345-4deb-bb98-4852b588dc46
# ╠═cea06d2a-d549-4d4d-a0fa-402a5def8536
# ╠═47a5b8b4-11c8-460f-a91e-a6e05f912ea6
# ╠═28bbbdb6-2ce5-4bfd-bf00-d6add78c38b9
# ╠═5d73c7a8-d5e0-4da2-b9fb-39e924cb913e
# ╠═fcad4298-c839-4f8c-9e9f-19dce1ce60a3
