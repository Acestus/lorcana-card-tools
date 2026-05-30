#!/bin/bash
# Script to convert Lorcana card list from detailed format to fabled.csv format
# Usage: ./convert input.csv output.csv

if [ $# -ne 2 ]; then
    echo "Usage: $0 input.csv output.csv"
    echo "Converts detailed Lorcana card format to simplified fabled format"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

# Convert the format using awk
awk -F'\t' 'NR==1{next} {
  # Extract card number from Card # column (remove /204)
  gsub("/204", "", $2)
  cardnum = sprintf("%03d", $2)
  
  # Get card name and rarity
  name = $3
  rarity = $6
  
  # Convert single letter rarities to full names
  if (rarity == "C") rarity = "Common"
  else if (rarity == "UC") rarity = "Uncommon" 
  else if (rarity == "R") rarity = "Rare"
  else if (rarity == "SR") rarity = "Super Rare"
  else if (rarity == "L") rarity = "Legendary"
  else if (rarity == "EP") rarity = "Epic"
  else if (rarity == "E") rarity = "Enchanted"
  else if (rarity == "I") rarity = "Iconic"
  
  # Output in fabled format: number, FALSE, FALSE, name, rarity
  print cardnum "\tFALSE\tFALSE\t" name "\t" rarity
}' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Conversion complete: $INPUT_FILE -> $OUTPUT_FILE"
