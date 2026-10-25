#!/usr/bin/env bash

# --- Configuration ---
ORGANIZER_ID="${1:-"9037398032"}"
OUTPUT_DIR="${2:-"."}"

API_URL="https://www.eventbrite.nl/organizer-profile/api/organizers/$ORGANIZER_ID"
# past-events/ only returns past events and events/ only upcoming ones; both share the same format
ENDPOINTS=("past-events" "events")
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

# --- Fetch all past and upcoming events ---
echo "Fetching events for organizer $ORGANIZER_ID..."
events="[]"
for endpoint in "${ENDPOINTS[@]}"; do
    page=1
    while true; do
        response=$(curl -sf -A "Mozilla/5.0" "$API_URL/$endpoint/?page=$page&pageSize=$PAGE_SIZE")
        if [[ -z "$response" ]]; then
            echo "Error: could not fetch page $page of $endpoint from Eventbrite." >&2
            exit 1
        fi

        count=$(jq '.events | length' <<< "$response")
        events=$(jq -s '.[0] + .[1].events' <(echo "$events") <(echo "$response"))

        if (( count < PAGE_SIZE )); then
            break
        fi
        page=$((page + 1))
    done
done
echo "Found $(jq length <<< "$events") events."
today=$(date +%Y-%m-%d)

# --- Main Loop ---
jq -c '.[]' <<< "$events" | while read -r event; do
    date_post=$(jq -r '.start_date' <<< "$event")
    file_name="${date_post:2}"
    output_md_file="$CONTENT_PATH/$file_name.md"

    echo "Processing $file_name..."
    # Files of upcoming editions ("vindt plaats") are regenerated, so they pick up
    # cancellations and switch to "vond plaats" once the date has passed
    action="Created"
    if [[ -f "$output_md_file" ]]; then
        if ! grep -q "vindt plaats" "$output_md_file"; then
            echo "   Warning: Markdown file '$file_name.md' already exists. Skipping file creation."
            continue
        fi
        action="Updated"
    fi

    # Strings are written with @json so quotes in event names stay valid YAML
    jq -r --arg default_image "$DEFAULT_IMAGE" --arg today "$today" '
        (.primary_venue.name // "") as $venue
        | (.primary_venue.address.city // "Oss") as $city
        | (.is_cancelled or (.name | test("GEANNULEERD"; "i"))) as $cancelled
        | (if .start_date >= $today then "vindt" else "vond" end) as $verb
        | "---",
          "title: \(.name | @json)",
          "date: \(.start_date | @json)",
          "image: \((.image.image_sizes.medium // (.image.url // "" | select(. != "")) // $default_image) | @json)",
          "description: \((
              if $cancelled then "Deze Dojo is geannuleerd."
              elif $venue != "" then "Deze Dojo \($verb) plaats bij \($venue) in \($city)."
              else "Deze Dojo \($verb) plaats in \($city)."
              end) | @json)",
          "eventbrite: \(.url | @json)",
          "tag: \"Edities\"",
          "---"
    ' <<< "$event" > "$output_md_file"

    echo "   $action $file_name.md"
done
