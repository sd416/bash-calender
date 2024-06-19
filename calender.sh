#!/bin/bash

CALENDAR_DIR="$HOME/.calendar"
mkdir -p "$CALENDAR_DIR"

# Function to parse common date words and handle date formats
parse_date() {
  case "$1" in
    today)
      date '+%Y-%m-%d' ;;
    tomorrow)
      date -v +1d '+%Y-%m-%d' 2>/dev/null || date -d tomorrow '+%Y-%m-%d' ;;
    next\ monday)
      date -v +monday '+%Y-%m-%d' 2>/dev/null || date -d 'next monday' '+%Y-%m-%d' ;;
    *[0-9]*) # Handle dates containing numbers directly 
      if date -j -f "%Y-%m-%d" "$1" "+%Y-%m-%d" >/dev/null 2>&1; then
        date -j -f "%Y-%m-%d" "$1" "+%Y-%m-%d" 2>/dev/null || date -d "$1" '+%Y-%m-%d'
      else
        echo "Invalid date format. Use YYYY-MM-DD." >&2
        exit 1
      fi ;;
    *)  
      # Extract the month name for relative dates like "June next month"
      month_name=$(echo "$1" | awk '{print $1}')
      date -v +1m -j -f "%B" "$month_name" "+%Y-%m-%d" 2>/dev/null || date -d "$month_name next month" '+%Y-%m-%d' ;;
  esac
}

# Function to normalize time format to uppercase AM/PM
normalize_time() {
  echo "$1" | sed -E 's/am/AM/; s/pm/PM/; s/([0-9]+)(am|pm)/\1\U\2/g'
}

# Function to create, update, or delete a meeting with validation
create_update_delete_meeting() {
  read -p "Enter date (YYYY-MM-DD or today, tomorrow, etc.): " input_date
  date=$(parse_date "$input_date")

  if [[ -f "$CALENDAR_DIR/$date" ]]; then
    echo "Existing meetings on $date:"
    cat "$CALENDAR_DIR/$date"
    echo
  else
    touch "$CALENDAR_DIR/$date"
  fi

  while true; do
    read -p "Do you want to: (c)reate, (u)pdate, (d)elete, or (e)xit? " action
    case $action in
      c)
        read -p "Enter time (e.g., 1PM-2PM): " time
        time=$(normalize_time "$time")
        if ! [[ $time =~ ^[0-9]{1,2}(AM|PM)-[0-9]{1,2}(AM|PM)$ ]]; then
          echo "Invalid time format. Use HH(AM|PM)-HH(AM|PM)."
          continue
        fi

        read -p "Enter description: " description
        if echo "$time - $description" >> "$CALENDAR_DIR/$date"; then
          echo "Meeting saved for $date at $time."
        else
          echo "Error saving meeting. Please try again."
        fi
        ;;
      u)
        read -p "Enter time of meeting to update (e.g., 1PM-2PM): " time
        time=$(normalize_time "$time")
        if grep -q "^$time - " "$CALENDAR_DIR/$date"; then
          read -p "Enter new description: " description
          if sed -i "" "/^$time - /c\\
$time - $description
" "$CALENDAR_DIR/$date"; then
            echo "Meeting updated for $date at $time."
          else
            echo "Error updating meeting. Please try again."
          fi
        else
          echo "No meeting found at that time."
        fi
        ;;
      d)
        read -p "Enter time of meeting to delete (e.g., 1PM-2PM): " time
        time=$(normalize_time "$time")
        if sed -i "" "/^$time - /d" "$CALENDAR_DIR/$date"; then
          echo "Meeting deleted for $date at $time."
        else
          echo "Error deleting meeting. Please try again."
        fi
        ;;
      e) return ;;
      *) echo "Invalid option. Please try again." ;;
    esac
    break # Exit the loop after creation, update, or delete
  done
}

# Function to view meetings
view_meetings() {
  date=$1

  if [[ -z "$date" ]]; then
    date=$(date '+%Y-%m-%d')
  fi

  if [[ -f "$CALENDAR_DIR/$date" ]]; then
    echo "Meetings on $date:"
    cat "$CALENDAR_DIR/$date"
  else
    echo "No meetings on $date."
  fi

  echo "Do you want to view more meetings?"
  echo "1. View by Date"
  echo "2. View by Week"
  echo "3. View by Month"
  echo "4. No"
  read -p "Choose a view option: " view_option

  case $view_option in
    1)
      read -p "Enter date (e.g., today, tomorrow, next monday, 2024-06-19): " input_date
      view_meetings "$(parse_date "$input_date")"
      ;;
    2)
      view_meetings_by_week
      ;;
    3)
      view_meetings_by_month
      ;;
    4)
      echo "Returning to main menu."
      ;;
    *)
      echo "Invalid option. Please try again."
      ;;
  esac
}

# Function to view meetings by week
view_meetings_by_week() {
  read -p "Enter starting date of the week (e.g., today, 2024-06-19): " input_date
  start_date=$(parse_date "$input_date")

  for i in {0..6}; do
    date=$(date -v +${i}d '+%Y-%m-%d' 2>/dev/null || date -d "$start_date + $i day" '+%Y-%m-%d')
    if [[ -f "$CALENDAR_DIR/$date" ]]; then
      echo "Meetings on $date:"
      cat "$CALENDAR_DIR/$date"
    else
      echo "No meetings on $date."
    fi
    echo
  done
}

# Function to view meetings by month
view_meetings_by_month() {
  read -p "Enter month and year (e.g., 2024-06): " month_year
  for file in "$CALENDAR_DIR"/"$month_year"-*; do
    if [[ -f "$file" ]]; then
      date=$(basename "$file")
      echo "Meetings on $date:"
      cat "$file"
      echo
    fi
  done
}

# Main menu
while true; do
  read -p "Do you want to: (c)reate, (u)pdate, (d)elete, (v)iew, or (e)xit? " action
  case $action in
    c|u|d) create_update_delete_meeting ;;
    v) view_meetings ;;
    e) break ;;
    *) echo "Invalid option. Please try again." ;;
  esac
done
