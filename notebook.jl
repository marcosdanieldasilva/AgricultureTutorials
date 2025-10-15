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


# ╔═╡ Cell order:
# ╟─791e27f0-a9f0-11f0-91ec-7b09a9a9c617
# ╠═11f0bb79-7ca1-4b95-becb-e86018853763
# ╠═8115b77f-817c-495d-8f9f-4e325b424dae
# ╠═23bb4bbe-0187-4ac5-bd23-82ea6c50c520
# ╠═d09bebca-7acf-4cea-b873-067844cd84a9
