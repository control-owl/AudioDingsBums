#!/bin/bash
# version 2024-11-01


show_error() {
    yad --title "Error" --text "$1" --button "OK"
}

# -------- INPUT FILE

input_m4b_file=$(yad --file --title="Select the .m4b File" --file-filter="*.m4b")

if [[ $? -ne 0 ]]; then
    echo "User cancelled."
    exit 1
fi

if [[ -z "$input_m4b_file" ]]; then
    echo "No file selected. Exiting."
    exit 1
fi

# -------- OUTPUT DIRECTORY

output_mp3_dir=$(yad --file --directory --title="Select output directory")

if [[ $? -ne 0 ]]; then
    echo "User cancelled."
    exit 1
fi

mkdir -p "$output_mp3_dir"

# -------- CHAPTER INFO

start_chapter=$(yad --title "Starting chapter number" \
            --form \
            --field="First chapter::NUM" 0!0..1!1!0 \
            --button "Cancel":1 \
            --button "OK":0
)

start_chapter=$(echo "$start_chapter" | cut -d '|' -f 1)

if [[ $? -ne 0 ]]; then
    echo "User cancelled."
    exit 1
fi

echo "start_chapter: $start_chapter"

book_name=$(basename "$input_m4b_file" | rev | cut -d '.' -f 2- | rev)

info_file="$output_mp3_dir/${book_name%.*}.info"

chapters=$(ffprobe -v error -select_streams v:0 -show_entries chapter=start_time,end_time -of json "$input_m4b_file")

echo "input_m4b_file: $input_m4b_file"
echo "output_mp3_dir: $output_mp3_dir"

echo "book_name: $book_name"
echo "info_file: $info_file"

{
    chapter_number=$start_chapter

    echo "$chapters" | jq -c '.chapters[]' | while read -r chapter; do
        start_time=$(echo "$chapter" | jq -r '.start_time')
        end_time=$(echo "$chapter" | jq -r '.end_time')

        echo "Chapter $chapter_number - $start_time - $end_time"

        chapter_number=$((chapter_number + 1))
    done
} > "$info_file"


# -------- MP3s

output_dir="$output_mp3_dir/$book_name"
echo "output_dir: $output_dir"
mkdir -p "$output_dir"

mapfile -t chapters < "$info_file"

for line in "${chapters[@]}"; do
    echo "Processing line: $line"
    # [[ -z "$line" ]] && continue
    
    chapter_number=$(echo "$line" | cut -d'-' -f1 | xargs)
    start_time=$(echo "$line" | cut -d'-' -f2 | xargs)
    end_time=$(echo "$line" | cut -d'-' -f3 | xargs)

    echo "chapter_number: ${chapter_number}"
    echo "start_time: ${start_time}"
    echo "end_time: ${end_time}"

    

    output_file="$output_dir/${chapter_number}.mp3"
    echo "output_file: $output_file"


    ffmpeg -ss "$start_time" -i "$input_m4b_file" -to "$end_time" -map 0:a -c:a libmp3lame "$output_file"
    

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to convert $output_file"
        continue  # Skip to the next iteration
    else
        echo "convert done"
    fi

    line_number=$((line_number + 1))
done


echo "done"
exit 1