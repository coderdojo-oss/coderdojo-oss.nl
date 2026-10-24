#!/usr/bin/env bash

# --- Configuration ---
ORGANIZER_ID="${1:-"9037398032"}"
OUTPUT_DIR="${2:-"."}"

API_URL="https://www.eventbrite.nl/organizer-profile/api/organizers/$ORGANIZER_ID/past-events/"
PAGE_SIZE=12
DEFAULT_IMAGE="/images/dojos/default.svg"

# --- Setup ---
CONTENT_PATH="$OUTPUT_DIR/content/edities"

for tool in curl jq; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: '$tool' is required but not found." >&2
        exit 1
    fi
done

mkdir -p "$CONTENT_PATH"

# --- Fetch all past events ---
echo "Fetching past events for organizer $ORGANIZER_ID..."
events="[]"
page=1
while true; do
    response=$(curl -sf -A "Mozilla/5.0" "$API_URL?page=$page&pageSize=$PAGE_SIZE")
    if [[ -z "$response" ]]; then
        echo "Error: could not fetch page $page from Eventbrite." >&2
        exit 1
    fi

    count=$(jq '.events | length' <<< "$response")
    events=$(jq -s '.[0] + .[1].events' <(echo "$events") <(echo "$response"))

    if (( count < PAGE_SIZE )); then
        break
    fi
    page=$((page + 1))
done
echo "Found $(jq length <<< "$events") events."

# --- Main Loop ---
jq -c '.[]' <<< "$events" | while read -r event; do
    date_post=$(jq -r '.start_date' <<< "$event")
    file_name="${date_post:2}"
    output_md_file="$CONTENT_PATH/$file_name.md"

    echo "Processing $file_name..."
    if [[ -f "$output_md_file" ]]; then
        echo "   Warning: Markdown file '$file_name.md' already exists. Skipping file creation."
        continue
    fi

    # Strings are written with @json so quotes in event names stay valid YAML
    jq -r --arg default_image "$DEFAULT_IMAGE" '
        (.primary_venue.name // "") as $venue
        | (.primary_venue.address.city // "Oss") as $city
        | (.is_cancelled or (.name | test("GEANNULEERD"; "i"))) as $cancelled
        | "---",
          "title: \(.name | @json)",
          "date: \(.start_date | @json)",
          "image: \((.image.image_sizes.medium // (.image.url // "" | select(. != "")) // $default_image) | @json)",
          "description: \((
              if $cancelled then "Deze Dojo is geannuleerd."
              elif $venue != "" then "Deze Dojo vond plaats bij \($venue) in \($city)."
              else "Deze Dojo vond plaats in \($city)."
              end) | @json)",
          "eventbrite: \(.url | @json)",
          "tag: \"Edities\"",
          "---"
    ' <<< "$event" > "$output_md_file"

    echo "   Created $file_name.md"
done
