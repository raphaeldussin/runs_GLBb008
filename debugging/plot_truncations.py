#!/usr/bin/env python

import re
import pandas as pd
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import sys
from datetime import datetime, timedelta

# Pattern for U:

#                (North: +)
#
#     [h-+]-------------------[h++]
#       |                       |
#       |                       |
# (West: -)                     (East: +)
#     [h-0]--------(U)--------[h+0]
#     (T-, S-)                (T+, S+)
#       |                       |
#       |                       |
#     [h--]-------------------[h+-]
#
#                (South: -)

def parse_mom6_truncations(filepath, direction_label):
    """Parses MOM6 log files and extracts truncation violation data."""
    
    coord_pattern = re.compile(r"\(\s*([+-]?[\d\.]+)\s*([EW])\s*([+-]?[\d\.]+)\s*([NS])\s*\)")
    #coord_pattern = re.compile(r"\(\s*([\d\.]+)\s*([EW])\s*([\d\.]+)\s*([NS])\s*\)")
    
    var_patterns = {
        'T_minus': re.compile(r"^T-:\s*([-\d\.E\+]+)"),
        'T_plus':  re.compile(r"^T\+:\s*([-\d\.E\+]+)"),
        'S_minus': re.compile(r"^S-:\s*([-\d\.E\+]+)"),
        'S_plus':  re.compile(r"^S\+:\s*([-\d\.E\+]+)"),
        # Matches h-0 (West cell for U) OR h0- (South cell for V)
        'h_minus': re.compile(r"^h(?:-0|0-):\s*([-\d\.E\+]+)"), 
        # Matches h+0 (East cell for U) OR h0+ (North cell for V)
        'h_plus':  re.compile(r"^h(?:\+0|0\+):\s*([-\d\.E\+]+)") 
    }

    data = []
    current_event = {}

    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                
                # Detect new truncation event header
                if "violation at" in line:
                    if current_event:
                        current_event['direction'] = direction_label
                        data.append(current_event)
                    current_event = {}
                    
                    coord_match = coord_pattern.search(line)
                    if coord_match:
                        lon_val, lon_dir, lat_val, lat_dir = coord_match.groups()
                        lon = float(lon_val) if lon_dir == 'E' else -float(lon_val)
                        lat = float(lat_val) if lat_dir == 'N' else -float(lat_val)
                        current_event['lon'] = lon
                        current_event['lat'] = lat
                
                # Extract state variables if we are inside an event block
                elif current_event is not None:
                    for var_name, pattern in var_patterns.items():
                        match = pattern.search(line)
                        if match:
                            current_event[var_name] = float(match.group(1))

            # Append the final event
            if current_event:
                current_event['direction'] = direction_label
                data.append(current_event)
                
    except FileNotFoundError:
        print(f"Warning: {filepath} not found.")

    return pd.DataFrame(data)

def plot_truncation_map(df):
    """Plots U and V truncation locations on a global map."""
    fig = plt.figure(figsize=(12, 6))
    ax = plt.axes(projection=ccrs.PlateCarree())
    
    ax.add_feature(cfeature.LAND, facecolor='lightgray')
    ax.add_feature(cfeature.OCEAN, facecolor='azure')
    ax.add_feature(cfeature.COASTLINE, linewidth=0.5)
    ax.gridlines(draw_labels=True, linestyle='--', alpha=0.5)

    # Plot U truncations
    df_u = df[df['direction'] == 'U']
    if not df_u.empty:
        ax.scatter(df_u['lon'], df_u['lat'], transform=ccrs.PlateCarree(),
                   color='red', marker='*', s=100, zorder=5, label='U-Truncations')
        
    # Plot V truncations
    df_v = df[df['direction'] == 'V']
    if not df_v.empty:
        ax.scatter(df_v['lon'], df_v['lat'], transform=ccrs.PlateCarree(),
                   color='blue', marker='*', s=100, zorder=5, label='V-Truncations')
    
    ax.set_extent([0.01,359.99,-89.9,89.9], crs=ccrs.PlateCarree())
    plt.title('MOM6 Truncation Locations (U and V)')
    plt.legend(loc='lower left')
    plt.show()

def plot_truncation_map_npolar(df):
    """Plots U and V truncation locations on a global map."""
    fig = plt.figure(figsize=(12, 6))
    ax = plt.axes(projection=ccrs.NorthPolarStereo())
    
    ax.add_feature(cfeature.LAND, facecolor='lightgray')
    ax.add_feature(cfeature.OCEAN, facecolor='azure')
    ax.add_feature(cfeature.COASTLINE, linewidth=0.5)
    ax.gridlines(draw_labels=True, linestyle='--', alpha=0.5)

    # Plot U truncations
    df_u = df[df['direction'] == 'U']
    if not df_u.empty:
        ax.scatter(df_u['lon'], df_u['lat'], transform=ccrs.PlateCarree(),
                   color='red', marker='*', s=100, zorder=5, label='U-Truncations')
        
    # Plot V truncations
    df_v = df[df['direction'] == 'V']
    if not df_v.empty:
        ax.scatter(df_v['lon'], df_v['lat'], transform=ccrs.PlateCarree(),
                   color='blue', marker='*', s=100, zorder=5, label='V-Truncations')
    
    ax.set_extent([0.01,359.99,50,89.9], crs=ccrs.PlateCarree())
    plt.title('MOM6 Truncation Locations (U and V)')
    plt.legend(loc='lower left')
    plt.show()

def plot_histograms(df):
    """Plots overlaid histograms for U and V cell state variables."""
    if df.empty:
        return
        
    df['T_avg'] = (df['T_minus'] + df['T_plus']) / 2
    df['S_avg'] = (df['S_minus'] + df['S_plus']) / 2
    df['h_avg'] = (df['h_minus'] + df['h_plus']) / 2

    df_u = df[df['direction'] == 'U']
    df_v = df[df['direction'] == 'V']

    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    
    kwargs = dict(alpha=0.6, bins=20, edgecolor='black')
    
    # Thickness Histogram
    axes[0,0].hist(df_u['h_avg'].dropna(), color='red', label='U', **kwargs)
    axes[0,0].set_title('Cell Thickness (h) Distribution')
    axes[0,0].set_xlabel('Thickness (m)')
    axes[0,0].set_ylabel('Frequency')
    axes[0,0].legend()

    axes[1,0].hist(df_v['h_avg'].dropna(), color='blue', label='V', **kwargs)
    axes[1,0].set_title('Cell Thickness (h) Distribution')
    axes[1,0].set_xlabel('Thickness (m)')
    axes[1,0].set_ylabel('Frequency')
    axes[1,0].legend()

    # Temperature Histogram
    axes[0,1].hist(df_u['T_avg'].dropna(), color='red', label='U', **kwargs)
    axes[0,1].set_title('Temperature Distribution')
    axes[0,1].set_xlabel('Temperature (°C)')
    axes[0,1].legend()

    axes[1,1].hist(df_v['T_avg'].dropna(), color='blue', label='V', **kwargs)
    axes[1,1].set_title('Temperature Distribution')
    axes[1,1].set_xlabel('Temperature (°C)')
    axes[1,1].legend()

    # Salinity Histogram
    axes[0,2].hist(df_u['S_avg'].dropna(), color='red', label='U', **kwargs)
    axes[0,2].set_title('Salinity Distribution')
    axes[0,2].set_xlabel('Salinity (psu)')
    axes[0,2].legend()

    axes[1,2].hist(df_v['S_avg'].dropna(), color='blue', label='V', **kwargs)
    axes[1,2].set_title('Salinity Distribution')
    axes[1,2].set_xlabel('Salinity (psu)')
    axes[1,2].legend()

    plt.tight_layout()
    plt.show()


def count_mom6_truncations(log_file_path):
  """Parses a MOM6 log file for velocity violations/truncations

  and returns a monthly time series of the truncation counts.
  """
  # Pattern matches lines starting with "Time <year> <day_of_year> <hour>"
  pattern = re.compile(r"Time\s+(\d{4})\s+(\d+)\s+([\d\.]+)")

  timestamps = []

  with open(log_file_path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
      match = pattern.search(line)
      if match:
        year = int(match.group(1))
        doy = int(match.group(2))

        # Convert Year and Day of Year (DOY) to a datetime object
        base_date = datetime(year, 1, 1) + timedelta(days=doy)
        event_time = base_date
        timestamps.append(event_time)

  if not timestamps:
    return pd.Series(dtype="int", name="truncation_count")

  # Create a pandas Series, set index to datetimes, and aggregate by month
  df = pd.DataFrame({"truncation": 1}, index=timestamps)
  monthly_series = df.resample("MS").sum()["truncation"].fillna(0).astype(int)
  monthly_series.index.name = "month"

  return monthly_series


def plot_truncations(monthly_series_u, monthly_series_v):
  """Plots the monthly time series of MOM6 truncations."""
  fig, ax = plt.subplots(figsize=(10, 5))

  ax.plot(
      monthly_series_u.index,
      monthly_series_u.values,
      marker="o",
      linestyle="-",
      color="firebrick",
      linewidth=2,
      markersize=6,
      label="U truncs"
  )
  ax.plot(
      monthly_series_v.index,
      monthly_series_v.values,
      marker="o",
      linestyle="-",
      color="cyan",
      linewidth=2,
      markersize=6,
      label="V truncs"
  )

  ax.legend()
  ax.set_title("MOM6 Monthly Truncation Count", fontsize=14, pad=12)
  ax.set_xlabel("Month", fontsize=12)
  ax.set_ylabel("Number of Truncations", fontsize=12)
  ax.grid(True, linestyle="--", alpha=0.6)

  # Format x-axis dates cleanly
  ax.xaxis.set_major_formatter(plt.matplotlib.dates.DateFormatter("%Y-%m"))
  fig.autofmt_xdate()

  plt.tight_layout()
  plt.show()

if __name__ == "__main__":
    # 1. Parse both log files
    pathrun = sys.argv[-1]
    df_u = parse_mom6_truncations(f"{pathrun}/truncations_u.txt", "U")
    df_v = parse_mom6_truncations(f"{pathrun}/truncations_v.txt", "V")

    df_ts_u = count_mom6_truncations(f"{pathrun}/truncations_u.txt")
    df_ts_v = count_mom6_truncations(f"{pathrun}/truncations_v.txt")
    
    # Combine the dataframes
    df_all = pd.concat([df_u, df_v], ignore_index=True)

    if (not df_ts_u.empty) or (not df_ts_v.empty):
        plot_truncations(df_ts_u, df_ts_v)
    
    if not df_all.empty:
        print(f"Successfully parsed {len(df_u)} U-truncations and {len(df_v)} V-truncations.")
        
        # 2. Plot the map
        plot_truncation_map(df_all)

        #plot_truncation_map_npolar(df_all)
        
        # 3. Plot the histograms
        plot_histograms(df_all)
    else:
        print("No truncations found or failed to parse.")
