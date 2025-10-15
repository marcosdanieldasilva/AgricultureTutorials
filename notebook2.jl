### A Pluto.jl notebook ###
# v0.20.19

using Markdown
using InteractiveUtils

# ╔═╡ c290bc62-a9b7-11f0-95e8-19a4e8cead96
begin
	# 1 Install necessary packages (silently)
	using Pkg;
	
	Pkg.add(["GeoStats", "GeoIO", "Downloads", "GLMakie", "GeometryBasics", "Tyler", "CSV", "DataFrames"]);
	
	# --- Core Geospatial Framework ---
	# The main package of the GeoStats.jl ecosystem, providing the core types and methods for geostatistical problems.
	using GeoStats
	
	# --- Input/Output Modules ---
	# Provides functions to load and save a variety of geospatial file formats (e.g., Shapefile, GeoPackage, GeoTIFF).
	using GeoIO
	# Standard library for downloading files from URLs (e.g., via HTTP/HTTPS).
	using Downloads
	
	# --- Visualization Modules ---
	# Imports the CairoMakie backend for creating high-quality, static plots (e.g., PNG, SVG, PDF). It's aliased as `Mke`.
	import GLMakie as Mke
	
	# --- Tabular Data Handling ---
	# A fast and flexible package for reading and writing comma-separated value (CSV) files.
	using CSV
	# Provides the `DataFrame` type, a powerful and feature-rich tool for working with tabular data in memory, similar to R's data.frame or pandas' DataFrame.
	using DataFrames
end

# ╔═╡ c0e65f71-fe02-433d-b5ee-6816fb553b63
begin
	using Tyler
	using Tyler.TileProviders
	using Tyler.MapTiles
	
	# Import the Rect2f type for defining a 2D rectangle.
	using GeometryBasics: Rect2f
end

# ╔═╡ 93609ebc-d1df-4901-afd7-d976616ce3c1
using Logging

# ╔═╡ 3e8fcf3f-a592-4141-a7d0-fdb811587865
img = GeoIO.load(raw"C:\Users\marco\OneDrive\Área de Trabalho\rgb_ex1.tif")

# ╔═╡ aa82044e-459b-4828-8796-5db4ff3a7aad
# Print a summary of the GeoTable's columns, including their data types and other properties.
describe(img)

# ╔═╡ 336884c1-6042-4d81-bfa2-abd11bc5176f
ColorView(color=RGB; low=0.02, high=0.98, cname="RGB") = LowHigh(; low, high) → Map(color => cname)

# ╔═╡ 8fcdaba7-c8be-4304-8e9c-91f85568f2b2
# Select and rename the first three bands to R, G, and B.
rgb  = img |> Select(1=> "R", 2 => "G", 3 => "B") |> ColorView()

# ╔═╡ 727c3949-4451-4f1a-8658-84d971074ca7
# Display the final rgb image in the interactive viewer.
rgb |> viewer

# ╔═╡ 75df71f8-a81c-4354-841a-32922b444279
viz(rgb.geometry, color = rgb.RGB)

# ╔═╡ 140f118e-8dae-4937-905c-35a82a856b6a
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

# ╔═╡ ecd83e21-cf44-467d-82d9-aca3573ee824
# Get bounding box in Lat/Lon (syntax shown here is not valid).
	box = boundingbox(rgb.geometry |> Proj(LatLon))

# ╔═╡ 2c4cf026-ab24-4111-8735-b0af6d4afce1
# Expand the extent.
	extent = extented_box(box)

# ╔═╡ c15537e5-7258-4903-9e1a-04ec9b56759b
# Choose Google Maps tile provider.
	provider = TileProviders.Google()

# ╔═╡ 140e0db4-ab06-40bf-9bda-ceb65b62622a
begin
    m = Tyler.Map(extent; provider);
    viz!(rgb.geometry |> Proj(WebMercator), color = rgb.RGB)
    m
end

# ╔═╡ 8bb611cd-6e83-4b3c-9bcc-739e19fceb22
# Function to convert numerical R, G, B values to the Hue color channel.
function to_hue(r, g, b)
    # Create an RGB color object from the numbers.
    rgb = RGB(r, g, b)
    # Convert the color from RGB to HSV (Hue, Saturation, Value).
    hsv = HSV(rgb)
    # Return only the Hue component.
    return hsv.h
end

# ╔═╡ 49efa02b-78cc-4a62-a9c3-3ea8a833857e
# Apply the `to_hue` function across the `rgb` GeoTable,
# creating a new column named "HUE" with the results.
img_hue = img |> Select(1=> "R", 2 => "G", 3 => "B") |> Map(["R","G","B"] => to_hue => "HUE")

# ╔═╡ 2b2fc1f9-5bbc-44f3-adf2-27d7d9e898e3
begin
	# Define a threshold by calculating the 70th percentile of the Hue values.
	q70 = quantile(img_hue.HUE, 0.7)
	
	# Define a function that returns `true` if a pixel's value is above the threshold.
	# This will be used to identify vegetation.
	isinside(x) = x > q70
	
	# Apply the classification function to the "HUE" column.
	# This creates a new GeoTable with a binary "label" column (`true` for vegetation).
	binary = img_hue |> Map("HUE" => isinside => "label")
	
	# Display the resulting binary mask in the interactive viewer.
	binary |> viewer
end

# ╔═╡ c3406440-12fb-4044-9ef9-e43ded33d48d
begin
	# Apply a Mode filter to smooth the binary mask.
	# This removes small, isolated pixels (salt-and-pepper noise).
	mask = binary |> ModeFilter()
	
	# Display the cleaned-up mask in the viewer.
	mask |> viewer
end

# ╔═╡ 96c98180-9102-459f-811e-86ad33ee4767
begin
	# Find all indices of the pixels that are `true` inside the mask.
	inds = findall(mask.label);
	
	# Use these indices to select only the pixels from the original `color` image.
	# The result is a new GeoTable containing only the pixels within the mask.
	masked_img = rgb[inds,:];
	
	# Display the resulting masked image in the viewer.
	masked_img |> viewer
end

# ╔═╡ 7a652e53-ea10-4401-91e5-c9e61da73db5
begin
	# Define the four corner points of a polygon.
p₁ = Point(296607.6, 4888188)
	p₂ = Point(296620.4, 4888188)
	p₃ = Point(296622.8, 4888244)
	p₄ = Point(296609.8, 4888244)
	
	# Create a Quadrangle geometry from the four points.
	quad = Quadrangle(p₁, p₂, p₃, p₄)
	
	# Discretize the quadrangle into a regular grid of 14x9 cells.
	plotgrid = discretize(quad, RegularDiscretization(14, 9))
	
	# Visualize the resulting grid, showing the segments of each cell.
	viz(plotgrid, showsegments=true)
end

# ╔═╡ 37ceb70a-3263-4b74-81fc-94405946f430
begin
	# Filtra a GeoTable criando uma "view" dos dados dentro da caixa
	subset_view = masked_img[quad, :]
	subset_view |> viewer
end

# ╔═╡ 003026c6-8b9b-430e-b990-137eac01f38f
data = CSV.read(raw"C:\Users\marco\OneDrive\Área de Trabalho\data_ex1.csv", DataFrame)

# ╔═╡ d1036764-033d-449c-9e3d-8426f9f4dec2
# Combine the tabular `data` with the `plotgrid` geometry to create a GeoTable.
gridtable = georef(data, plotgrid)

# ╔═╡ b684c5f7-1267-4654-9a88-9d9d8d204149
# ╠═╡ disabled = true
#=╠═╡
begin
	Pkg.add("Observables")
	using Observables
	
	begin
		Mke.activate!()
	  # --- Figure ---
	  # Create a new Figure with a specified size.
	  fig = Mke.Figure(size = (1000, 700))
	
	  # --- Overlaid Axes ---
	  # Create two axes in the same grid position.
	  ax_rgb  = Mke.Axis(fig[1, 1], title = "Layer Viewer")
	  ax_grid = Mke.Axis(fig[1, 1])
	
	  # Link the axes to synchronize pan and zoom.
	  Mke.linkaxes!(ax_rgb, ax_grid)
	
	  # Make the top axis transparent so the bottom one is visible.
	  Mke.hidespines!(ax_grid)
	  Mke.hidedecorations!(ax_grid)
	  ax_grid.backgroundcolor = :transparent
	
	  # --- Plots ---
	  # Plot the grid on the top axis.
	  viz!(ax_grid, plotgrid, alpha=0.0, showsegments = true)
	  # Plot the RGB image on the bottom axis.
	  viz!(ax_rgb, subset_view.geometry, color = subset_view.RGB)
	
	  # --- Controls ---
	  # Create a layout grid for the UI controls below the plot.
	  gl = Mke.GridLayout(fig[2, 1], tellwidth = false)
	
	  # Add a toggle for the RGB layer visibility.
	  Mke.Label(gl[1, 1], "Show RGB Layer")
	  toggle_rgb = Mke.Toggle(gl[1, 2], active = true)
	
	  # Add a toggle for the grid layer visibility.
	  Mke.Label(gl[2, 1], "Show Grid Layer")
	  toggle_grid = Mke.Toggle(gl[2, 2], active = true)
	
	  # Add a toggle to control the aspect ratio.
	  Mke.Label(gl[3, 1], "Fix Aspect Ratio")
	  toggle_aspect = Mke.Toggle(gl[3, 2], active = false)
	
	  # --- Callbacks ---
	  # Create a callback to toggle the RGB axis visibility.
	  on(toggle_rgb.active) do is_active
	      ax_rgb.scene.visible[] = is_active
	  end
	
	  # Create a callback to toggle the grid axis visibility.
	  on(toggle_grid.active) do is_active
	      ax_grid.scene.visible[] = is_active
	  end
	
	  # Create a callback to switch the aspect ratio.
	  on(toggle_aspect.active) do is_active
	    if is_active
	      # Lock the aspect ratio to the data's proportions.
	      ax_rgb.aspect[] = DataAspect()
	      ax_grid.aspect[] = DataAspect()
	    else
	      # Allow the aspect ratio to fill the available space.
	      ax_rgb.aspect[] = nothing
	      ax_grid.aspect[] = nothing
	    end
	  end
	
	  # Display the final interactive figure.
	  fig
	end
end
  ╠═╡ =#

# ╔═╡ 1b1216ed-fb40-4aca-98a1-7a716781962c
# ╠═╡ disabled = true
#=╠═╡
begin
	# Create a new Figure with a specified size.
	fig = Mke.Figure(size = (1000, 700))
	
	# --- Overlaid Axes ---
	# Create two axes in the same grid position. The bottom one will hold the image,
	# and the top one will hold the grid overlay.
	ax_rgb  = Mke.Axis(fig[1, 1], title = "Plots")
	ax_grid = Mke.Axis(fig[1, 1])
	
	# Link the axes so that pan and zoom are synchronized between them.
	Mke.linkaxes!(ax_rgb, ax_grid)
	
	# Make the top axis transparent so we can see the bottom axis through it.
	Mke.hidespines!(ax_grid)
	Mke.hidedecorations!(ax_grid)
	ax_grid.backgroundcolor = :transparent
	
	# --- Plots ---
	# Plot the grid geometry onto the top (transparent) axis.
	viz!(ax_grid, plotgrid, alpha=0.0, showsegments = true)
	# Plot the RGB image data onto the bottom axis.
	viz!(ax_rgb, subset_view.geometry, color = subset_view.RGB)
	
	# Display the final figure with both layers.
	fig

end
  ╠═╡ =#

# ╔═╡ Cell order:
# ╠═c290bc62-a9b7-11f0-95e8-19a4e8cead96
# ╠═3e8fcf3f-a592-4141-a7d0-fdb811587865
# ╠═aa82044e-459b-4828-8796-5db4ff3a7aad
# ╠═336884c1-6042-4d81-bfa2-abd11bc5176f
# ╠═8fcdaba7-c8be-4304-8e9c-91f85568f2b2
# ╠═727c3949-4451-4f1a-8658-84d971074ca7
# ╠═75df71f8-a81c-4354-841a-32922b444279
# ╠═140f118e-8dae-4937-905c-35a82a856b6a
# ╠═c0e65f71-fe02-433d-b5ee-6816fb553b63
# ╠═ecd83e21-cf44-467d-82d9-aca3573ee824
# ╠═2c4cf026-ab24-4111-8735-b0af6d4afce1
# ╠═c15537e5-7258-4903-9e1a-04ec9b56759b
# ╠═93609ebc-d1df-4901-afd7-d976616ce3c1
# ╠═140e0db4-ab06-40bf-9bda-ceb65b62622a
# ╠═8bb611cd-6e83-4b3c-9bcc-739e19fceb22
# ╠═49efa02b-78cc-4a62-a9c3-3ea8a833857e
# ╠═2b2fc1f9-5bbc-44f3-adf2-27d7d9e898e3
# ╠═c3406440-12fb-4044-9ef9-e43ded33d48d
# ╠═96c98180-9102-459f-811e-86ad33ee4767
# ╠═7a652e53-ea10-4401-91e5-c9e61da73db5
# ╠═37ceb70a-3263-4b74-81fc-94405946f430
# ╠═003026c6-8b9b-430e-b990-137eac01f38f
# ╠═d1036764-033d-449c-9e3d-8426f9f4dec2
# ╠═1b1216ed-fb40-4aca-98a1-7a716781962c
# ╠═b684c5f7-1267-4654-9a88-9d9d8d204149
